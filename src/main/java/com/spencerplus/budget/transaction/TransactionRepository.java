package com.spencerplus.budget.transaction;

import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface TransactionRepository extends JpaRepository<Transaction, UUID>{
	List<Transaction> findByCategoryId(UUID categoryId);
	List<Transaction> findByUserId(UUID userId);
	List<Transaction> findByCategoryIdAndTransactionDateBetween(UUID categoryId, LocalDate from, LocalDate to); 
	List<Transaction> findByCategoryIdAndTransactionDateGreaterThanEqual(UUID categoryId, LocalDate from); 
	List<Transaction> findByCategoryIdAndTransactionDateLessThanEqual(UUID categoryId, LocalDate to);
}
