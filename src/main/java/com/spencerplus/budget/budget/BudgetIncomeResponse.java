package com.spencerplus.budget.budget;

import java.time.LocalDate;
import java.util.UUID;

public record BudgetIncomeResponse (
	UUID budgetId,
	LocalDate asOf,
	long receivedThisMonthCents,
	long expectedThisMonthCents
) {}