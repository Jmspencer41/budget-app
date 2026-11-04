package com.spencerplus.budget.incomesource;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;
import com.spencerplus.budget.incomesource.IncomeSource.Frequency;

public record IncomeSourceResponse (
	UUID id,
	UUID userId,
	UUID budgetId,
	String name,
	long amountCents,
	Frequency frequency,
	boolean autoGenerate,
	LocalDate anchorDate,
	Integer secondPayDay,
	long receivedThisMonthCents,
	long expectedThisMonthCents,
	LocalDate nextPayDate,
	LocalDateTime createdAt
	) {
	public static IncomeSourceResponse fromEntity(IncomeSource incomeSource, long receivedThisMonthCents, long expectedThisMonthCents, LocalDate nextPayDate) {
		return new IncomeSourceResponse(
				incomeSource.getId(),
				incomeSource.getUserId(),
				incomeSource.getBudgetId(),
				incomeSource.getName(),
				incomeSource.getAmountCents(),
				incomeSource.getFrequency(),
				incomeSource.isAutoGenerate(),
				incomeSource.getAnchorDate(),
				incomeSource.getSecondPayDay(),
				receivedThisMonthCents,
				expectedThisMonthCents,
				nextPayDate,
				incomeSource.getCreatedAt()
		);
	}
}
