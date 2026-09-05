package com.spencerplus.budget.incomesource;

import java.time.LocalDate;
import java.util.UUID;

import com.spencerplus.budget.incomesource.IncomeSource.Frequency;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CreateIncomeSourceRequest (
	@NotNull UUID userId,
	@NotNull UUID budgetId,
	@NotBlank String name,
	@Positive long amountCents,
	@NotNull Frequency frequency,
	boolean autoGenerate,
	LocalDate nextPayDate
	
) {}
