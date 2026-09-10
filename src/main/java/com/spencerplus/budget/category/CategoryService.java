package com.spencerplus.budget.category;

import org.springframework.stereotype.Service;
import com.spencerplus.budget.category.Category.CategoryType;
import com.spencerplus.budget.category.Category.Frequency;
import com.spencerplus.budget.transaction.Transaction;
import com.spencerplus.budget.transaction.TransactionRepository;
import java.util.List;
import java.util.UUID;

@Service
public class CategoryService {
	
	private final CategoryRepository categoryRepository;
	private final TransactionRepository transactionRepository;
	
	public CategoryService(CategoryRepository categoryRepository, TransactionRepository transactionRepository) {
		this.categoryRepository = categoryRepository;
		this.transactionRepository = transactionRepository;
	}
	
	public Category createCategory(UUID budgetId, String name, CategoryType categoryType, Frequency frequency, long amountCents) {
		Category category = new Category();
		category.setBudgetId(budgetId);
		category.setName(name);
		category.setCategoryType(categoryType);
		category.setFrequency(frequency);
		category.setAmountCents(amountCents);
		return categoryRepository.save(category);
	}
	
	public long getRemainingAmount(UUID categoryId) {
        Category category = categoryRepository.findById(categoryId).orElseThrow(() -> new RuntimeException("Category not found"));
    
        List<Transaction> transactions = transactionRepository.findByCategoryId(categoryId);
        
        long totalSpent = 0;
        for (Transaction transaction : transactions) {
        	totalSpent += transaction.getAmountCents();
        }
        
        return category.getAmountCents() - totalSpent;
	}
	
	public List<Category> getCategoriesForBudget(UUID budgetId) {
		return categoryRepository.findByBudgetId(budgetId);
	}

}
