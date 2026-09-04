package com.spencerplus.budget.budget;

import org.springframework.stereotype.Service;
import java.util.UUID;

@Service
public class BudgetService {
	
	private final BudgetRepository budgetRepository;
	
	public BudgetService(BudgetRepository budgetRepository) {
		this.budgetRepository = budgetRepository;
	}

	public Budget createBudget(String title, UUID ownerId) {
		Budget budget = new Budget();
		budget.setTitle(title);
		budget.setOwnerId(ownerId);
		return budgetRepository.save(budget);
	}
}
