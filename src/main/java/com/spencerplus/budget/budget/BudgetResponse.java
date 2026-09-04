package com.spencerplus.budget.budget;

import java.time.LocalDateTime;
import java.util.UUID;

public record BudgetResponse(
    UUID id,
    String title,
    UUID ownerId,
    LocalDateTime createdAt
) {
    public static BudgetResponse fromEntity(Budget budget) {
        return new BudgetResponse(
            budget.getId(),
            budget.getTitle(),
            budget.getOwnerId(),
            budget.getCreatedAt()
        );
    }
}
