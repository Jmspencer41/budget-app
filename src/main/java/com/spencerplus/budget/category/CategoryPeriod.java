package com.spencerplus.budget.category;

import java.time.LocalDate;

public record CategoryPeriod( 
		LocalDate start, 
		LocalDate end 
) {}