package com.spencerplus.budget.category;

import org.springframework.stereotype.Service;
import com.spencerplus.budget.category.Category.CategoryType;
import com.spencerplus.budget.category.Category.Frequency;

import java.util.UUID;

@Service
public class CategoryService {
	
	private final CategoryRepository categoryRepository;
	
	public CategoryService(CategoryRepository categoryRepository) {
		this.categoryRepository = categoryRepository;
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

}
