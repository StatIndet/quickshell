#pragma once
#include <linux/input.h>

// EV_KEY is deliberately ignored: LED state belongs to the compositor/kernel.
struct KeyboardLedState {
    bool caps = false;
    bool num = false;
    bool dropped = false;

    // True requests an EVIOCGLED snapshot after a lost event frame.
    bool consume(const input_event &event)
    {
        if (event.type == EV_SYN && event.code == SYN_DROPPED) {
            dropped = true;
            return false;
        }
        if (dropped)
            return event.type == EV_SYN && event.code == SYN_REPORT;
        if (event.type == EV_LED) {
            if (event.code == LED_CAPSL)
                caps = event.value != 0;
            else if (event.code == LED_NUML)
                num = event.value != 0;
        }
        return false;
    }
};
