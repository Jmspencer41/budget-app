package com.spencerplus.budget.transaction;

import java.time.LocalDate;
import java.util.UUID;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record CreateTransactionRequest(
	
		@NotNull UUID categoryId,
		@NotNull UUID userId,
		@Size(max = 255) String merchant,
		@Size(max = 255) String description,
		@Positive long amountCents,
		@NotNull LocalDate transactionDate
	
	) {}
