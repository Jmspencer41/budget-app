package com.spencerplus.budget.incomesource;

import java.time.LocalDate;
import java.util.UUID;
import org.springframework.stereotype.Service;

import com.spencerplus.budget.incomesource.IncomeSource.Frequency;

@Service
public class IncomeSourceService {

	private final IncomeSourceRepository incomeSourceRepository;
	
	public IncomeSourceService(IncomeSourceRepository incomeSourceRepository) {
		this.incomeSourceRepository = incomeSourceRepository;
	}
	
	public IncomeSource createIncomeSource(UUID userId, UUID budgetId, String name, long amountCents, Frequency frequency, boolean autoGenerate, LocalDate nextPayDate) {
		IncomeSource incomeSource = new IncomeSource();
		incomeSource.setUserId(userId);
		incomeSource.setBudgetId(budgetId);
		incomeSource.setName(name);
		incomeSource.setAmountCents(amountCents);
		incomeSource.setFrequency(frequency);
		incomeSource.setAutoGenerate(autoGenerate);
		incomeSource.setNextPayDate(nextPayDate);
		return incomeSourceRepository.save(incomeSource);
	}
}
