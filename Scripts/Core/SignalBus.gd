extends Node
class_name Sig_Bus
# Autoload named: SignalBus

# --- Micro Signals (The Tallyman listens to these during the dive) ---
signal trash_picked_up
signal lionfish_culled(scale_factor: float)
signal coral_planted(type: CoralData.CoralType, global_pos: Vector3)

# We discussed a penalty for accidentally hitting a coral. 
# Let's add that to the bus while we are here.
signal coral_damaged(unique_id: String) 

# --- Currency Signals ---
signal on_coin_earned(amount: int, balance: int)
signal on_coin_spent(amount: int, balance: int)

# --- Macro Signals (The Overseer listens to these to manage the campaign) ---
# To start a dive, we must know WHICH wreck we are entering.
signal dive_started(wreck_id: String)
# To end a dive, the Tallyman must pass its final ledger up to the Overseer.
signal dive_completed(wreck_id: String, dive_report: Dictionary)
