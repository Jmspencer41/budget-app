package com.spencerplus.budget.transaction;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public record TransactionResponse(
		
		UUID id,
		UUID categoryId,
		UUID userId,
		String merchant,
		String description,
		long amountCents,
		LocalDate transactionDate,
		LocalDateTime createdAt
		
		) {

	public static TransactionResponse fromEntity(Transaction transaction) {
		return new TransactionResponse(
				transaction.getId(),
				transaction.getCategoryId(),
				transaction.getUserId(),
				transaction.getMerchant(),
				transaction.getDescription(),
				transaction.getAmountCents(),
				transaction.getTransactionDate(),
				transaction.getCreatedAt()
		);
		
	}
	
}
