// Returns the next active position when navigating a combobox list.
// -1 means no item is active (cleared by pressing up from position 0).
// Clamps at the bottom boundary — does not wrap.
export function navigateCombobox(currentPosition, direction, length) {
  if (length == 0) return -1
  if (direction == "down") return Math.min(currentPosition + 1, length - 1)
  if (direction == "up") return Math.max(currentPosition - 1, -1)
  return currentPosition
}
