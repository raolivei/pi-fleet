import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function getSeverityColor(severity: number): string {
  if (severity >= 95) return '#8B0000' // Dark red
  if (severity >= 85) return '#DC143C' // Crimson
  if (severity >= 75) return '#FF4500' // Orange red
  if (severity >= 65) return '#FF8C00' // Dark orange
  if (severity >= 55) return '#FFA500' // Orange
  if (severity >= 45) return '#FFD700' // Gold
  if (severity >= 35) return '#ADFF2F' // Green yellow
  if (severity >= 25) return '#7FFF00' // Chartreuse
  return '#32CD32' // Lime green
}

export function getSeverityGradient(severity: number): string {
  const color = getSeverityColor(severity)
  return `linear-gradient(135deg, ${color}33 0%, ${color}66 100%)`
}

export function formatNumber(num: number): string {
  return new Intl.NumberFormat('en-US').format(num)
}

export function getComparisonColor(value: number, average: number): string {
  if (value > average * 1.2) return 'text-red-500'
  if (value < average * 0.8) return 'text-green-500'
  return 'text-yellow-500'
}

