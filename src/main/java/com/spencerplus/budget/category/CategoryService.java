package com.spencerplus.budget.category;

import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.category.Category.CategoryType;
import com.spencerplus.budget.category.Category.Frequency;
import com.spencerplus.budget.transaction.Transaction;
import com.spencerplus.budget.transaction.TransactionRepository;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit; 
import java.util.ArrayList; 
import java.util.List;
import java.util.UUID;

@Service
public class CategoryService {
	
	private static final int MAX_HISTORY_PERIODS = 60; // cap on how many periods one history request can return
	
	private final CategoryRepository categoryRepository;
	private final TransactionRepository transactionRepository;
	
	public CategoryService(CategoryRepository categoryRepository, TransactionRepository transactionRepository) {
		this.categoryRepository = categoryRepository;
		this.transactionRepository = transactionRepository;
	}
	
	public Category createCategory(UUID budgetId, String name, CategoryType categoryType, Frequency frequency, long amountCents, LocalDate anchorDate) {
		if (categoryType == CategoryType.RECURRING) {
			if (frequency == null || anchorDate == null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Recurring categories require a frequency and anchor date");
			}
		} else if (categoryType == CategoryType.GOAL) {
			if (frequency != null || anchorDate != null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal categories cannot have a frequency or anchor date");
			}
		}
		
		Category category = new Category();
		category.setBudgetId(budgetId);
		category.setName(name);
		category.setCategoryType(categoryType);
		category.setFrequency(frequency);
		category.setAmountCents(amountCents);
		category.setAnchorDate(anchorDate);
		return categoryRepository.save(category);
	}
	
	public void deleteCategory(UUID categoryId) {
		if (!categoryRepository.existsById(categoryId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found");
		}
		categoryRepository.deleteById(categoryId);
	}
	
	public Category getCategory(UUID categoryId) { 
		return categoryRepository.findById(categoryId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found")); // missing category becomes a 404
	}
	
	public long getRemainingAmount(UUID categoryId) {
		Category category = getCategory(categoryId); // uses the shared lookup now
		
		List<Transaction> transactions; // filled differently for goals and recurring categories
		if (category.getCategoryType() == CategoryType.GOAL) { // goals have no periods
			transactions = transactionRepository.findByCategoryId(categoryId); // so every contribution ever counts
		} else { // recurring categories reset each period
			CategoryPeriod period = getCurrentPeriod(category); // the period that contains today
			transactions = transactionRepository.findByCategoryIdAndTransactionDateBetween(categoryId, period.start(), period.end()); // only this period's spending
		}
		
		return category.getAmountCents() - sumAmounts(transactions); // limit minus what was spent
	}
	
	public CategoryPeriod getCurrentPeriod(Category category) { // used by the controller to fill periodStart and periodEnd
		if (category.getCategoryType() == CategoryType.GOAL) { // goals have no period
			return null; // CategoryResponse turns this into null fields
		}
		return getPeriodContaining(category.getFrequency(), category.getAnchorDate(), LocalDate.now()); // the period containing today
	}
	
	public List<CategoryPeriodResponse> getHistory(UUID categoryId, int periods) { // newest period first
		if (periods < 1 || periods > MAX_HISTORY_PERIODS) { // keep requests bounded
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "periods must be between 1 and " + MAX_HISTORY_PERIODS); // bad count is a 400
		}
		
		Category category = getCategory(categoryId); // 404 if it does not exist
		if (category.getCategoryType() == CategoryType.GOAL) { // goals have no periods to list
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal categories have no period history"); // client should use the transaction list instead
		}
		
		Frequency frequency = category.getFrequency(); // pulled out to keep the loop readable
		LocalDate anchorDate = category.getAnchorDate(); // same
		long currentIndex = getPeriodIndex(frequency, anchorDate, LocalDate.now()); // which period number today falls in (0 is the anchor's period)
		
		List<CategoryPeriodResponse> history = new ArrayList<>(); // result list
		for (long i = currentIndex; i >= 0 && i > currentIndex - periods; i--) { // walk backward, stop at the anchor or the requested count
			LocalDate start = getPeriodStart(frequency, anchorDate, i); // first day of period i
			LocalDate end = getPeriodStart(frequency, anchorDate, i + 1).minusDays(1); // day before the next period starts
			long spent = sumAmounts(transactionRepository.findByCategoryIdAndTransactionDateBetween(categoryId, start, end)); // spending inside this period
			history.add(new CategoryPeriodResponse(start, end, category.getAmountCents(), spent, category.getAmountCents() - spent)); // one history row
		}
		return history;
	}
	
	public CategoryPeriod getPeriodContaining(Frequency frequency, LocalDate anchorDate, LocalDate date) { // public so it can be unit tested directly
		long index = getPeriodIndex(frequency, anchorDate, date); // which period the date falls in
		LocalDate start = getPeriodStart(frequency, anchorDate, index); // that period's first day
		LocalDate end = getPeriodStart(frequency, anchorDate, index + 1).minusDays(1); // that period's last day
		return new CategoryPeriod(start, end);
	}
	
	private long getPeriodIndex(Frequency frequency, LocalDate anchorDate, LocalDate date) { // period number containing date, counting from the anchor
		if (date.isBefore(anchorDate)) { // anchor is in the future
			return 0; // treat the first period as the current one
		}
		
		long index = switch (frequency) { // rough estimate from the calendar difference
			case DAILY -> ChronoUnit.DAYS.between(anchorDate, date);
			case WEEKLY -> ChronoUnit.WEEKS.between(anchorDate, date);
			case BIWEEKLY -> ChronoUnit.WEEKS.between(anchorDate, date) / 2;
			case MONTHLY -> ChronoUnit.MONTHS.between(anchorDate, date);
			case QUARTERLY -> ChronoUnit.MONTHS.between(anchorDate, date) / 3;
			case SEMIANNUALLY -> ChronoUnit.MONTHS.between(anchorDate, date) / 6;
			case YEARLY -> ChronoUnit.YEARS.between(anchorDate, date);
		};
		
		while (index > 0 && getPeriodStart(frequency, anchorDate, index).isAfter(date)) { // estimate overshot (month-end clamping can cause this)
			index--; // step back one period
		}
		while (!getPeriodStart(frequency, anchorDate, index + 1).isAfter(date)) { // next period already started on or before date
			index++; // step forward one period
		}
		return index;
	}
	
	private LocalDate getPeriodStart(Frequency frequency, LocalDate anchorDate, long index) { // first day of period number index
		return switch (frequency) { // always measured from the anchor, never chained, so month-end dates don't drift
			case DAILY -> anchorDate.plusDays(index);
			case WEEKLY -> anchorDate.plusWeeks(index);
			case BIWEEKLY -> anchorDate.plusWeeks(index * 2);
			case MONTHLY -> anchorDate.plusMonths(index); // Jan 31 + 1 month clamps to Feb 28/29
			case QUARTERLY -> anchorDate.plusMonths(index * 3);
			case SEMIANNUALLY -> anchorDate.plusMonths(index * 6);
			case YEARLY -> anchorDate.plusYears(index);
		};
	}
	
	private long sumAmounts(List<Transaction> transactions) { // adds up transaction amounts
		long total = 0;
		for (Transaction transaction : transactions) {
			total += transaction.getAmountCents();
		}
		return total;
	}
	
	public List<Category> getCategoriesForBudget(UUID budgetId) {
		return categoryRepository.findByBudgetId(budgetId);
	}

}
