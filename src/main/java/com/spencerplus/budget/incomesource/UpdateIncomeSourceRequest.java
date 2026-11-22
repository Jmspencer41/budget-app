package com.spencerplus.budget.incomesource;

import java.time.LocalDate;
import com.spencerplus.budget.incomesource.IncomeSource.Frequency;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record UpdateIncomeSourceRequest (
	@NotBlank @Size(max = 100) String name,
	@Min(0) long amountCents,
	@NotNull Frequency frequency,
	LocalDate anchorDate,
	Integer secondPayDay
) {}