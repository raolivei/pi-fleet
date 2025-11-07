"use client";

import { motion } from "framer-motion";
import { StateData, US_AVERAGES } from "@/data/states";
import {
  formatNumber,
  getComparisonColor,
  getSeverityColor,
} from "@/lib/utils";
import { Scale, Skull, Zap, Car, Users, Building2 } from "lucide-react";

interface StatePopupProps {
  state: StateData;
  onClose: () => void;
}

export default function StatePopup({ state, onClose }: StatePopupProps) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -100, scale: 0.9 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      exit={{ opacity: 0, x: -100, scale: 0.9 }}
      transition={{ type: "spring", damping: 25, stiffness: 300 }}
      className="absolute left-6 top-32 bottom-6 w-[400px] z-20 overflow-hidden"
    >
      <div className="h-full backdrop-blur-2xl bg-gradient-to-br from-white/10 to-white/5 rounded-3xl shadow-2xl border border-white/20 overflow-y-auto">
        {/* Header with gradient */}
        <div
          className="p-6 relative overflow-hidden"
          style={{
            background: `linear-gradient(135deg, ${getSeverityColor(
              state.severity
            )}33 0%, ${getSeverityColor(state.severity)}66 100%)`,
          }}
        >
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.2, type: "spring" }}
          >
            <h2 className="text-4xl font-bold text-white mb-2">{state.name}</h2>
            <p className="text-white/80 text-sm font-medium">
              {state.abbr} • {state.category}
            </p>
          </motion.div>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
          {/* Severity Score */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
          >
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 rounded-lg bg-white/10">
                <Scale className="w-5 h-5 text-white" />
              </div>
              <h3 className="text-white font-semibold text-lg">Law Severity</h3>
            </div>
            <div className="space-y-2">
              <div className="flex items-end gap-2">
                <motion.span
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ delay: 0.2, type: "spring" }}
                  className="text-5xl font-bold text-white"
                >
                  {state.severity}
                </motion.span>
                <span className="text-white/60 text-lg mb-2">/100</span>
              </div>
              <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${state.severity}%` }}
                  transition={{ delay: 0.3, duration: 1, ease: "easeOut" }}
                  className="h-full rounded-full"
                  style={{ backgroundColor: getSeverityColor(state.severity) }}
                />
              </div>
              <div className="flex items-center gap-2 mt-2">
                <Skull className="w-4 h-4 text-white/70" />
                <p className="text-white/80 text-sm">{state.deathPenalty}</p>
              </div>
            </div>
          </motion.div>

          {/* Crime Statistics */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <h3 className="text-white font-semibold text-lg mb-3">
              Crime Statistics (per 100k)
            </h3>
            <div className="space-y-3">
              <StatRow
                icon={<Skull className="w-4 h-4" />}
                label="Murder Rate"
                value={state.murderRate}
                average={US_AVERAGES.murder}
                delay={0.3}
              />
              <StatRow
                icon={<Zap className="w-4 h-4" />}
                label="Gun Deaths"
                value={state.gunDeathRate}
                average={US_AVERAGES.gun}
                delay={0.35}
              />
              <StatRow
                icon={<Car className="w-4 h-4" />}
                label="Traffic Deaths"
                value={state.trafficFatalityRate}
                average={US_AVERAGES.traffic}
                delay={0.4}
              />
            </div>
          </motion.div>

          {/* Population & Incarceration */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            <h3 className="text-white font-semibold text-lg mb-3">
              Demographics
            </h3>
            <div className="grid grid-cols-2 gap-3">
              <div className="backdrop-blur-xl bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="flex items-center gap-2 mb-2">
                  <Users className="w-4 h-4 text-white/70" />
                  <span className="text-white/70 text-xs font-medium">
                    Population
                  </span>
                </div>
                <p className="text-white text-xl font-bold">
                  {formatNumber(state.population)}
                </p>
              </div>
              <div className="backdrop-blur-xl bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="flex items-center gap-2 mb-2">
                  <Building2 className="w-4 h-4 text-white/70" />
                  <span className="text-white/70 text-xs font-medium">
                    Incarceration
                  </span>
                </div>
                <p className="text-white text-xl font-bold">
                  {state.incarcerationRate}
                </p>
                <p className="text-white/60 text-xs mt-1">per 100k</p>
              </div>
            </div>
          </motion.div>

          {/* Notes */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            <div className="backdrop-blur-xl bg-blue-500/10 rounded-xl p-4 border border-blue-500/20">
              <p className="text-white/80 text-sm leading-relaxed">
                <strong className="text-white">Note:</strong> {state.notes}
              </p>
            </div>
          </motion.div>
        </div>
      </div>
    </motion.div>
  );
}

interface StatRowProps {
  icon: React.ReactNode;
  label: string;
  value: number;
  average: number;
  delay: number;
}

function StatRow({ icon, label, value, average, delay }: StatRowProps) {
  const comparisonColor = getComparisonColor(value, average);
  const percentDiff = (((value - average) / average) * 100).toFixed(0);
  const isAbove = value > average;

  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay }}
      className="backdrop-blur-xl bg-white/5 rounded-xl p-3 border border-white/10"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="text-white/70">{icon}</div>
          <span className="text-white/80 text-sm font-medium">{label}</span>
        </div>
        <div className="text-right">
          <p className="text-white text-lg font-bold">{value.toFixed(1)}</p>
          <p className={`text-xs font-medium ${comparisonColor}`}>
            {isAbove ? "+" : ""}
            {percentDiff}% vs US avg
          </p>
        </div>
      </div>
    </motion.div>
  );
}
