import type { ReactNode } from "react";
import { Tooltip } from "./Tooltip";

interface KpiCardProps {
  label: string;
  value: string | number;
  tone?: "danger" | "warning" | "good" | "info" | "neutral";
  detail?: string;
  tooltip?: string;
  icon: ReactNode;
  onClick?: () => void;
  actionLabel?: string;
}

export function KpiCard({ label, value, tone = "neutral", detail, tooltip, icon, onClick, actionLabel }: KpiCardProps) {
  const content = (includeTooltip: boolean) => (
    <>
      <div className="kpi-icon" aria-hidden="true">
        {icon}
      </div>
      <div>
        <div className="kpi-value">{value}</div>
        <div className="kpi-label">
          {label}
          {includeTooltip && tooltip ? <Tooltip label={`${label} help`} text={tooltip} /> : null}
        </div>
        {detail ? <div className="kpi-detail">{detail}</div> : null}
      </div>
    </>
  );

  if (onClick) {
    return (
      <div className={`kpi-card interactive ${tone}`}>
        <button type="button" className="kpi-card-button" onClick={onClick} aria-label={actionLabel ?? `Open ${label}`}>
          {content(false)}
        </button>
        {tooltip ? (
          <span className="kpi-card-help">
            <Tooltip label={`${label} help`} text={tooltip} />
          </span>
        ) : null}
      </div>
    );
  }

  return (
    <div className={`kpi-card ${tone}`}>
      {content(true)}
    </div>
  );
}
