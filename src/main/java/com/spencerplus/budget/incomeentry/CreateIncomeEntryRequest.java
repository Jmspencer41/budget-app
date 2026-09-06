package com.spencerplus.budget.incomeentry;

import java.time.LocalDate;
import java.util.UUID;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CreateIncomeEntryRequest(

	@NotNull UUID incomeSourceId,
	@Positive long amountCents,
	@NotNull LocalDate receivedDate
	) 
{}
