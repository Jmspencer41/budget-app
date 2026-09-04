package com.spencerplus.budget.incomesources;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "income_sources")
public class IncomeSources {

    @Id
    @GeneratedValue
    private UUID id;
    
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @Column(name = "budget_id", nullable = false)
    private UUID budgetId;
    
    @Column(nullable = false)
    private String name;
                
    @Column(name = "amount_cents", nullable = false)
    private long amountCents;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Frequency frequency;
    
    public enum Frequency { DAILY, WEEKLY, BIWEEKLY, SEMIMONTHLY, MONTHLY, IRREGULAR }
    
    @Column(name = "auto_generate", nullable = false)
    private boolean autoGenerate;
        
    @Column(name = "next_pay_date")
    private LocalDate nextPayDate;
    
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
    
    
    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    
    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }
    
    public UUID getBudgetId() { return budgetId; }
    public void setBudgetId(UUID budgetId) { this.budgetId = budgetId; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public long getAmountCents() { return amountCents; }
    public void setAmountCents(long amountCents) { this.amountCents = amountCents; }
    
    public Frequency getFrequency() { return frequency; }
    public void setFrequency( Frequency frequency) { this.frequency = frequency; }
    
    public LocalDate getNextPayDate() { return nextPayDate; }
    public void setNextPayDate(LocalDate nextPayDate) { this.nextPayDate = nextPayDate; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt( LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    
}
