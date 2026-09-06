package com.spencerplus.budget.incomeentry;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "income_entries")
public class IncomeEntry {
	
	@Id
	@GeneratedValue
	private UUID id;
	
	@Column(name = "income_source_id", nullable = false)
	private UUID incomeSourceId;
	
	@Column(name = "amount_cents", nullable = false)
	private long amountCents;
	
	@Column(name = "received_date", nullable = false)
	private LocalDate receivedDate;
	
	@Column(name = "created_at", nullable = false)
	private LocalDateTime createdAt = LocalDateTime.now();
	
	public UUID getId() { return id; }
	public void setId(UUID id) { this.id = id; }
	
	public UUID getIncomeSourceId() { return incomeSourceId; }
	public void setIncomeSourceId( UUID incomeSourceId ) { this.incomeSourceId = incomeSourceId; }
	
	public long getAmountCents() { return amountCents; }
	public void setAmountCents( long amountCents) { this.amountCents = amountCents; }
	
	public LocalDate getReceivedDate() { return receivedDate; }
	public void setReceivedDate( LocalDate receivedDate) { this.receivedDate = receivedDate; }
	
	public LocalDateTime getCreatedAt() { return createdAt; }
	public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
	
}
