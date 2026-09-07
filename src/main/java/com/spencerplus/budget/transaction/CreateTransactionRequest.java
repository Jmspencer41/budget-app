package com.spencerplus.budget.transaction;

import java.time.LocalDate;
import java.util.UUID;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CreateTransactionRequest(
	
		@NotNull UUID categoryId,
		@NotNull UUID userId,
		String merchant,
		String description,
		@Positive long amountCents,
		@NotNull LocalDate transactionDate
	
	) {}
