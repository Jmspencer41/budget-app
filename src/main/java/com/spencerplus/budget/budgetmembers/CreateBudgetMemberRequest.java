package com.spencerplus.budget.budgetmembers;

import java.util.UUID;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import jakarta.validation.constraints.NotNull;

public record CreateBudgetMemberRequest(

	@NotNull UUID budgetId,
	@NotNull UUID userId,
	@NotNull Role role
	
) {}
