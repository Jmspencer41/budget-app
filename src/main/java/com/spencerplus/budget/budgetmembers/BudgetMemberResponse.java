package com.spencerplus.budget.budgetmembers;

import java.util.UUID;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;

public record BudgetMemberResponse(UUID id, UUID budgetId, UUID userId, Role role) {
	public static BudgetMemberResponse fromEntity(BudgetMember budgetMember) {
		return new BudgetMemberResponse(budgetMember.getId(), budgetMember.getBudgetId(), budgetMember.getUserId(), budgetMember.getRole());
	}
}
