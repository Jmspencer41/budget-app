package com.spencerplus.budget.category;

import java.time.LocalDateTime;
import java.util.UUID;
import com.spencerplus.budget.category.Category.CategoryType;
import com.spencerplus.budget.category.Category.Frequency;

public record CategoryResponse(
		
		UUID id,
		UUID budgetId,
		String name,
		CategoryType categoryType,
		Frequency frequency,
		long amountCents,
		LocalDateTime createdAt
		
) {
	
	public static CategoryResponse fromEntity(Category category) {
		return new CategoryResponse(
				category.getId(),
				category.getBudgetId(),
				category.getName(),
				category.getCategoryType(),
				category.getFrequency(),
				category.getAmountCents(),
				category.getCreatedAt()
		);
	
	}
	
}
