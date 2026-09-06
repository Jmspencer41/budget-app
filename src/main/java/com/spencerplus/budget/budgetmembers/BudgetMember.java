package com.spencerplus.budget.budgetmembers;

import java.time.LocalDateTime;
import java.util.UUID;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "budget_members")
public class BudgetMember {
	
    @Id
    @GeneratedValue
	private UUID id;
    
    @Column(name = "budget_id", nullable = false)
	private UUID budgetId;
    
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;
 
	public enum Role { OWNER, EDITOR, VIEWER }
	
	@Column(name = "created_at", nullable = false)
	private LocalDateTime createdAt = LocalDateTime.now();;
	
	public UUID getId() { return id; }
	public void setId(UUID id) { this.id = id; }
	
	public UUID getBudgetId() { return budgetId; }
	public void setBudgetId( UUID budgetId ) { this.budgetId = budgetId; }
	
	public UUID getUserId() { return userId; }
	public void setUserId( UUID userId ) { this.userId = userId; }
	
	public Role getRole() { return role; }
	public void setRole( Role role ) { this.role = role; }
	
	public LocalDateTime getCreatedAt () { return createdAt; }
	public void setCreatedAt (LocalDateTime createdAt ) { this.createdAt = createdAt; }
	
	
}
