package com.spencerplus.budget.category;

import java.time.LocalDate;
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
		LocalDateTime createdAt,
		LocalDate anchorDate,
		LocalDate periodStart, 
		LocalDate periodEnd
		
) {
	
	public static CategoryResponse fromEntity(Category category, CategoryPeriod currentPeriod) {
		
		LocalDate periodStart = null; 
		LocalDate periodEnd = null;
		if (currentPeriod != null) { 
			periodStart = currentPeriod.start();
			periodEnd = currentPeriod.end();
		}
		
		return new CategoryResponse(
				category.getId(),
				category.getBudgetId(),
				category.getName(),
				category.getCategoryType(),
				category.getFrequency(),
				category.getAmountCents(),
				category.getCreatedAt(),
				category.getAnchorDate(),
				periodStart, 
				periodEnd
		);
	
	}
	
}
