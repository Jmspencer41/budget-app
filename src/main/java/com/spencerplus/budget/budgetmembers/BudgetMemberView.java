package com.spencerplus.budget.budgetmembers;

import java.util.UUID;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;

public record BudgetMemberView(UUID id, UUID budgetId, UUID userId, String name, Role role) {}
