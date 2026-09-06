package com.spencerplus.budget.incomeentry;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public record IncomeEntryResponse(
		UUID id,
		UUID incomeSourceId,
		long amountCents,
		LocalDate receivedDate,
		LocalDateTime createdAt
		) {
	public static IncomeEntryResponse fromEntity(IncomeEntry incomeEntry) {
		return new IncomeEntryResponse (
				incomeEntry.getId(),
				incomeEntry.getIncomeSourceId(),
				incomeEntry.getAmountCents(),
				incomeEntry.getReceivedDate(),
				incomeEntry.getCreatedAt()
		);
	}
}
