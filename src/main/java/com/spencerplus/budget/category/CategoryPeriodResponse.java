package com.spencerplus.budget.category;

import java.time.LocalDate;

public record CategoryPeriodResponse( 
		LocalDate periodStart, 
		LocalDate periodEnd, 
		long limitCents, 
		long spentCents, 
		long remainingCents 
) {}