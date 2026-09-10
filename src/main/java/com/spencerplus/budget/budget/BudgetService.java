package com.spencerplus.budget.budget;

import org.springframework.stereotype.Service;
import com.spencerplus.budget.category.Category;
import com.spencerplus.budget.category.CategoryRepository;
import com.spencerplus.budget.category.CategoryService;
import java.util.UUID;
import java.util.List;

@Service
public class BudgetService {
	
	private final BudgetRepository budgetRepository;
	private final CategoryRepository categoryRepository;
	private final CategoryService categoryService;
	
	public BudgetService(BudgetRepository budgetRepository, CategoryRepository categoryRepository, CategoryService categoryService) {
		this.budgetRepository = budgetRepository;
		this.categoryRepository = categoryRepository;
		this.categoryService = categoryService;
	}

	public Budget createBudget(String title, UUID ownerId) {
		Budget budget = new Budget();
		budget.setTitle(title);
		budget.setOwnerId(ownerId);
		return budgetRepository.save(budget);
	}
	
	public long getTotal(UUID budgetId) {
		List<Category> categories = categoryRepository.findByBudgetId(budgetId);
		
		long total = 0;
		for (Category category : categories) {
			total += category.getAmountCents();
		}
		
		return total;
	}
	
	public long getRemainingBalance(UUID budgetId) {
		
		List<Category> categories = categoryRepository.findByBudgetId(budgetId);
		
		long totalRemaining = 0;
		
		for (Category category : categories) {
			totalRemaining += categoryService.getRemainingAmount(category.getId());
		}
		
		return totalRemaining;
	}
}
