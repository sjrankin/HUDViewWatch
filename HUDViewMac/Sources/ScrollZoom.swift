//
//  ScrollZoom.swift
//  HUDViewMac
//
//  Created by Stuart Rankin on 11/22/26.
//

import SwiftUI
import AppKit

///Zooms with the mouse wheel or a two-finger scroll while the pointer is over the view this is the background of.
///`Change` is called with the scroll amount: positive to zoom in.
struct ScrollZoom: NSViewRepresentable
{
    let Change: (Double) -> Void

    func makeNSView(context Context: Context) -> ScrollZoomView
    {
        let View = ScrollZoomView()
        View.Change = Change
        return View
    }

    func updateNSView(_ View: ScrollZoomView, context Context: Context)
    {
        View.Change = Change
    }

    static func dismantleNSView(_ View: ScrollZoomView, coordinator Coordinator: ()) 
    {
        View.StopListening()
    }
}

///The view that listens. It never takes mouse clicks itself (see `hitTest`); it only watches scroll events over its own area.
final class ScrollZoomView: NSView
{
    var Change: ((Double) -> Void)? = nil
    private var Monitor: Any? = nil

    override func viewDidMoveToWindow()
    {
        super.viewDidMoveToWindow()
        StopListening()
        guard window != nil else
        {
            return
        }
        Monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)
        {
            [weak self] Event in
            guard let self, Event.window === self.window else
            {
                return Event
            }
            let Spot = self.convert(Event.locationInWindow, from: nil)
            guard self.bounds.contains(Spot) else
            {
                return Event
            }
            //A trackpad reports small precise amounts, a wheel whole lines.
            let Amount = Event.hasPreciseScrollingDeltas ? Event.scrollingDeltaY * 0.004 : Event.scrollingDeltaY * 0.03
            self.Change?(Amount)
            return nil
        }
    }

    func StopListening()
    {
        if let Monitor
        {
            NSEvent.removeMonitor(Monitor)
        }
        Monitor = nil
    }

    override func hitTest(_ Point: NSPoint) -> NSView?
    {
        nil
    }
}
