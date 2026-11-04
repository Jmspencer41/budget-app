package com.spencerplus.budget.incomesource;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.incomeentry.IncomeEntryService;
import com.spencerplus.budget.incomesource.IncomeSource.Frequency;

@Service
public class IncomeSourceService {

	private final IncomeSourceRepository incomeSourceRepository;
	private final IncomeEntryService incomeEntryService;
	
	public IncomeSourceService(IncomeSourceRepository incomeSourceRepository, IncomeEntryService incomeEntryService) {
		this.incomeSourceRepository = incomeSourceRepository;
		this.incomeEntryService = incomeEntryService;
	}
	
	public IncomeSource createIncomeSource(UUID userId, UUID budgetId, String name, long amountCents, Frequency frequency, boolean autoGenerate, LocalDate anchorDate, Integer secondPayDay) {
		validateSchedule(frequency, anchorDate, secondPayDay); // 400 before anything is saved
		
		IncomeSource incomeSource = new IncomeSource();
		incomeSource.setUserId(userId);
		incomeSource.setBudgetId(budgetId);
		incomeSource.setName(name);
		incomeSource.setAmountCents(amountCents);
		incomeSource.setFrequency(frequency);
		incomeSource.setAutoGenerate(autoGenerate);
		incomeSource.setAnchorDate(anchorDate);
		incomeSource.setSecondPayDay(secondPayDay);
		return incomeSourceRepository.save(incomeSource);
	}
	
	public IncomeSource updateIncomeSource(UUID incomeSourceId, String name, long amountCents, Frequency frequency, LocalDate anchorDate, Integer secondPayDay) {
		IncomeSource incomeSource = incomeSourceRepository.findById(incomeSourceId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Income source not found")); // 404 if it doesn't exist
		
		validateSchedule(frequency, anchorDate, secondPayDay); // same rules as create
		
		incomeSource.setName(name);
		incomeSource.setAmountCents(amountCents);
		incomeSource.setFrequency(frequency);
		incomeSource.setAnchorDate(anchorDate);
		incomeSource.setSecondPayDay(secondPayDay);
		return incomeSourceRepository.save(incomeSource);
	}
	
	public void deleteIncomeSource(UUID incomeSourceId) {
	    if (!incomeSourceRepository.existsById(incomeSourceId)) {
	        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Income source not found");
	    }
	    incomeSourceRepository.deleteById(incomeSourceId);
	}

	public List<IncomeSource> listForBudget(UUID budgetId) {
		return incomeSourceRepository.findByBudgetId(budgetId);
	}
	
	public IncomeSourceResponse toResponse(IncomeSource incomeSource, LocalDate asOf) {
		long receivedThisMonthCents = getReceivedCents(incomeSource, asOf);
		long expectedThisMonthCents = getExpectedCents(incomeSource, asOf);
		LocalDate nextPayDate = getNextPayDate(incomeSource, asOf);
		return IncomeSourceResponse.fromEntity(incomeSource, receivedThisMonthCents, expectedThisMonthCents, nextPayDate);
	}
	
	// ---------- validation ----------
	
	private void validateSchedule(Frequency frequency, LocalDate anchorDate, Integer secondPayDay) { // same rules as the database CHECK constraints, but as a clean 400
		if (frequency == Frequency.IRREGULAR) {
			if (anchorDate != null || secondPayDay != null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Irregular income cannot have an anchor date or second pay day");
			}
			return;
		}
		
		if (anchorDate == null) { // every scheduled frequency needs a starting payday
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Scheduled income requires an anchor date");
		}
		
		if (frequency == Frequency.SEMIMONTHLY) {
			if (secondPayDay == null || secondPayDay < 1 || secondPayDay > 31) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Semimonthly income requires a second pay day from 1 to 31");
			}
			if (secondPayDay == anchorDate.getDayOfMonth()) { // same day twice would count every paycheck double
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Second pay day must be different from the anchor date's day");
			}
		} else if (secondPayDay != null) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only semimonthly income can have a second pay day");
		}
	}
	
	// ---------- month totals ----------
	
	public long getReceivedCents(IncomeSource incomeSource, LocalDate asOf) { // money in from the 1st of asOf's month through asOf
		LocalDate monthStart = asOf.withDayOfMonth(1);
		if (incomeSource.getFrequency() == Frequency.IRREGULAR) {
			return incomeEntryService.getTotalCentsBetween(incomeSource.getId(), monthStart, asOf); // only what was actually logged
		}
		List<LocalDate> payDates = getPayDates(incomeSource, monthStart, asOf);
		return payDates.size() * incomeSource.getAmountCents();
	}
	
	public long getExpectedCents(IncomeSource incomeSource, LocalDate asOf) { // money in for the whole month asOf falls in
		LocalDate monthStart = asOf.withDayOfMonth(1);
		LocalDate monthEnd = asOf.withDayOfMonth(asOf.lengthOfMonth());
		if (incomeSource.getFrequency() == Frequency.IRREGULAR) {
			return incomeEntryService.getTotalCentsBetween(incomeSource.getId(), monthStart, monthEnd); // nothing to predict, so use what is logged
		}
		List<LocalDate> payDates = getPayDates(incomeSource, monthStart, monthEnd);
		return payDates.size() * incomeSource.getAmountCents();
	}
	
	public LocalDate getNextPayDate(IncomeSource incomeSource, LocalDate asOf) { // first payday after asOf (today's payday already counts as received)
		if (incomeSource.getFrequency() == Frequency.IRREGULAR) {
			return null;
		}
		LocalDate anchorDate = incomeSource.getAnchorDate();
		if (anchorDate.isAfter(asOf)) { // schedule hasn't started yet, and the anchor is always a payday
			return anchorDate;
		}
		List<LocalDate> payDates = getPayDates(incomeSource, asOf.plusDays(1), asOf.plusMonths(2)); // the longest gap is about a month, so two months always finds one
		if (payDates.isEmpty()) {
			return null;
		}
		return payDates.get(0);
	}
	
	// ---------- pay date generation ----------
	
	public List<LocalDate> getPayDates(IncomeSource incomeSource, LocalDate from, LocalDate to) { // every payday from `from` to `to`, both days included, oldest first
		List<LocalDate> payDates = new ArrayList<>();
		if (incomeSource.getFrequency() == Frequency.IRREGULAR) {
			return payDates; // no schedule
		}
		
		LocalDate anchorDate = incomeSource.getAnchorDate();
		LocalDate start = from;
		if (start.isBefore(anchorDate)) { // nothing is paid before the anchor
			start = anchorDate;
		}
		if (start.isAfter(to)) {
			return payDates; // empty range
		}
		
		switch (incomeSource.getFrequency()) {
			case WEEKLY -> addEveryNDays(payDates, anchorDate, 7, start, to);
			case BIWEEKLY -> addEveryNDays(payDates, anchorDate, 14, start, to);
			case MONTHLY -> addMonthly(payDates, anchorDate, start, to);
			case SEMIMONTHLY -> addSemimonthly(payDates, anchorDate, incomeSource.getSecondPayDay(), start, to);
			default -> { } // IRREGULAR handled above
		}
		return payDates;
	}
	
	private void addEveryNDays(List<LocalDate> payDates, LocalDate anchorDate, int stepDays, LocalDate start, LocalDate to) {
		long daysFromAnchor = ChronoUnit.DAYS.between(anchorDate, start);
		long index = (daysFromAnchor + stepDays - 1) / stepDays; // round up to the first payday on or after start
		LocalDate payDate = anchorDate.plusDays(index * stepDays);
		while (!payDate.isAfter(to)) {
			payDates.add(payDate);
			index++;
			payDate = anchorDate.plusDays(index * stepDays); // always measured from the anchor, never chained
		}
	}
	
	private void addMonthly(List<LocalDate> payDates, LocalDate anchorDate, LocalDate start, LocalDate to) {
		long index = ChronoUnit.MONTHS.between(anchorDate, start);
		if (index > 0) {
			index--; // step back one in case month-end clamping made the estimate overshoot
		}
		LocalDate payDate = anchorDate.plusMonths(index);
		while (payDate.isBefore(start)) { // walk forward to the first payday on or after start
			index++;
			payDate = anchorDate.plusMonths(index);
		}
		while (!payDate.isAfter(to)) {
			payDates.add(payDate);
			index++;
			payDate = anchorDate.plusMonths(index); // Jan 31 + 1 month clamps to Feb 28/29, then Mar 31 again
		}
	}
	
	private void addSemimonthly(List<LocalDate> payDates, LocalDate anchorDate, int secondPayDay, LocalDate start, LocalDate to) {
		int firstDay = Math.min(anchorDate.getDayOfMonth(), secondPayDay); // earlier day of the month goes first
		int secondDay = Math.max(anchorDate.getDayOfMonth(), secondPayDay);
		
		YearMonth month = YearMonth.from(start);
		YearMonth lastMonth = YearMonth.from(to);
		while (!month.isAfter(lastMonth)) {
			LocalDate firstDate = month.atDay(Math.min(firstDay, month.lengthOfMonth())); // the 31st becomes the 30th, 29th, or 28th in short months
			LocalDate secondDate = month.atDay(Math.min(secondDay, month.lengthOfMonth()));
			
			if (!firstDate.isBefore(start) && !firstDate.isAfter(to)) {
				payDates.add(firstDate);
			}
			if (!secondDate.equals(firstDate) && !secondDate.isBefore(start) && !secondDate.isAfter(to)) { // e.g. 30th and 31st both land on Feb 28, count it once
				payDates.add(secondDate);
			}
			month = month.plusMonths(1);
		}
	}
}
