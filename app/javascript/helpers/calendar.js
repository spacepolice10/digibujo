// Returns an array of day numbers (1–N) padded with nulls to fill a 7-column grid.
// Pass any Date within the target month.
export function calendarDays(date) {
  const year = date.getFullYear()
  const month = date.getMonth()
  const firstDay = new Date(year, month, 1).getDay()
  const totalDays = new Date(year, month + 1, 0).getDate()
  const cells = [...Array(firstDay).fill(null), ...Array.from({ length: totalDays }, (_, i) => i + 1)]
  const trailing = (7 - cells.length % 7) % 7
  return [...cells, ...Array(trailing).fill(null)]
}
