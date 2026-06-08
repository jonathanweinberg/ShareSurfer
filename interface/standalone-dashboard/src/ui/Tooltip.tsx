import { useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { HelpCircle } from "lucide-react";

interface TooltipProps {
  label: string;
  text: string;
}

export function Tooltip({ label, text }: TooltipProps) {
  const id = useId();
  const triggerRef = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState({ left: 12, top: 12, placement: "top" as "top" | "bottom" });

  useLayoutEffect(() => {
    if (!open || !triggerRef.current) {
      return;
    }

    const rect = triggerRef.current.getBoundingClientRect();
    const bubbleWidth = Math.min(300, Math.max(220, window.innerWidth - 24));
    const left = Math.min(Math.max(12, rect.left + rect.width / 2 - bubbleWidth / 2), window.innerWidth - bubbleWidth - 12);
    const placement = rect.top < 130 ? "bottom" : "top";
    const top = placement === "bottom" ? rect.bottom + 8 : rect.top - 8;
    setPosition({ left, top, placement });
  }, [open, text]);

  return (
    <span className="tooltip-wrap">
      <button
        ref={triggerRef}
        type="button"
        className="tooltip-trigger"
        aria-label={label}
        aria-describedby={open ? id : undefined}
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        onClick={() => setOpen((current) => !current)}
      >
        <HelpCircle aria-hidden="true" size={15} strokeWidth={2.2} />
      </button>
      {open
        ? createPortal(
            <span
              id={id}
              role="tooltip"
              className="tooltip-bubble"
              style={{
                position: "fixed",
                left: position.left,
                top: position.top,
                transform: position.placement === "top" ? "translateY(-100%)" : "none"
              }}
            >
              {text}
            </span>,
            document.body
          )
        : null}
    </span>
  );
}
