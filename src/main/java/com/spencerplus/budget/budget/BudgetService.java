package com.spencerplus.budget.budget;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.budgetmembers.BudgetMember;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import com.spencerplus.budget.budgetmembers.BudgetMemberRepository;
import com.spencerplus.budget.category.Category;
import com.spencerplus.budget.category.CategoryRepository;
import com.spencerplus.budget.category.CategoryService;
import com.spencerplus.budget.incomesource.IncomeSource;
import com.spencerplus.budget.incomesource.IncomeSourceService;
import com.spencerplus.budget.category.Category.CategoryType;
import com.spencerplus.budget.config.AccessService;
import java.time.LocalDate;
import java.util.UUID;
import java.util.ArrayList;
import java.util.List;

@Service
public class BudgetService {
	
	private final BudgetRepository budgetRepository;
	private final CategoryRepository categoryRepository;
	private final CategoryService categoryService;
	private final BudgetMemberRepository budgetMemberRepository;
	private final IncomeSourceService incomeSourceService;
	private final AccessService accessService;
	
	public BudgetService(
			BudgetRepository budgetRepository,
			CategoryRepository categoryRepository,
			CategoryService categoryService,
			BudgetMemberRepository budgetMemberRepository,
			IncomeSourceService incomeSourceService,
			AccessService accessService) {
		this.budgetRepository = budgetRepository;
		this.categoryRepository = categoryRepository;
		this.categoryService = categoryService;
		this.budgetMemberRepository = budgetMemberRepository;
		this.incomeSourceService = incomeSourceService;
		this.accessService = accessService;
	}
	
	@Transactional
	public Budget createBudget(String title, UUID ownerId) {
		accessService.requireSelf(ownerId);
		Budget budget = new Budget();
		budget.setTitle(title);
		budget.setOwnerId(ownerId);
		Budget saved = budgetRepository.save(budget);

		BudgetMember owner = new BudgetMember();
		owner.setBudgetId(saved.getId());
		owner.setUserId(ownerId);
		owner.setRole(Role.OWNER);
		budgetMemberRepository.save(owner);
		return saved;
	}

	  public List<Budget> listForUser(UUID userId) {
	      accessService.requireSelf(userId);
	      List<UUID> budgetIds = new ArrayList<>();
	      for (BudgetMember member : budgetMemberRepository.findByUserId(userId)) {
	          budgetIds.add(member.getBudgetId());
	      }
	      return budgetRepository.findAllById(budgetIds);
	  }

	  public void deleteBudget(UUID budgetId) {
	    if (!budgetRepository.existsById(budgetId)) {
	        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Budget not found");
	    }
	    accessService.requireOwner(budgetId);
	    budgetRepository.deleteById(budgetId);
	  }

	public Budget updateBudget(UUID budgetId, String title) {
		Budget budget = budgetRepository.findById(budgetId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Budget not found"));
		accessService.requireOwner(budgetId);
		budget.setTitle(title);
		return budgetRepository.save(budget);
	}
	
	public long getTotal(UUID budgetId) {
		accessService.requireMember(budgetId);
		List<Category> categories = categoryRepository.findByBudgetId(budgetId);
		
		long total = 0;
		for (Category category : categories) {
			if (category.getCategoryType() == CategoryType.GOAL) {
				continue;
			}
			total += category.getAmountCents();
		}
		
		return total;
	}
	
	public long getRemainingBalance(UUID budgetId) {
		accessService.requireMember(budgetId);
		List<Category> categories = categoryRepository.findByBudgetId(budgetId);
		
		long totalRemaining = 0;
		
		for (Category category : categories) {
			if (category.getCategoryType() == CategoryType.GOAL) {
				continue;
			}
			totalRemaining += categoryService.getRemainingAmount(category.getId());
		}
		
		return totalRemaining;
	}
	
	public BudgetIncomeResponse getIncome(UUID budgetId, LocalDate asOf) { // every income source on this budget, added together
		accessService.requireMember(budgetId);
		if (!budgetRepository.existsById(budgetId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Budget not found");
		}
		
		long received = 0;
		long expected = 0;
		for (IncomeSource incomeSource : incomeSourceService.listForBudget(budgetId)) { // goes through the service, not the repository
			received += incomeSourceService.getReceivedCents(incomeSource, asOf);
			expected += incomeSourceService.getExpectedCents(incomeSource, asOf);
		}
		return new BudgetIncomeResponse(budgetId, asOf, received, expected);
	}
}
