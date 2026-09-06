package com.spencerplus.budget.incomeentry;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.UUID;

public interface IncomeEntryRepository extends JpaRepository<IncomeEntry, UUID> {
    List<IncomeEntry> findByIncomeSourceId(UUID incomeSourceId);
}
