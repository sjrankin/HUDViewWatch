//
//  PlacesView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import SwiftUI
import CoreLocation

///Every place: the user's own and the built-in ones. Any place can be edited or deleted. Changes go to the watch automatically; the
///top section shows how that is going.
struct PlacesView: View
{
    @Environment(POIStore.self) private var Store
    @Environment(WatchLink.self) private var Link
    @Environment(RadarSettings.self) private var Settings
    @ObservedObject var Compass: HeadingProvider
    ///The place being added or edited, shown in a sheet.
    @State private var Editing: PlaceDraft? = nil
    @State private var SearchText = ""
    @State private var ConfirmingReset = false

    ///The places in name order, narrowed to the ones matching the search text.
    func Matching(_ Places: [POI]) -> [POI]
    {
        Places
            .filter { SearchText.isEmpty || $0.Name.localizedStandardContains(SearchText) }
            .sorted { $0.Name.localizedStandardCompare($1.Name) == .orderedAscending }
    }

    func Remove(_ Offsets: IndexSet, From Places: [POI])
    {
        Store.Delete(IDs: Set(Offsets.map { Places[$0].id }))
    }

    var body: some View
    {
        let Mine = Matching(Store.Custom)
        let BuiltIn = Matching(Store.BuiltIn)
        NavigationStack
        {
            List
            {
                Section("Apple Watch")
                {
                    Text(Link.Status)
                    Button(Link.IsSending ? "Sending…" : "Send to Watch Now",
                           systemImage: Link.IsSending ? "checkmark.circle.fill" : "applewatch.radiowaves.left.and.right")
                    {
                        Link.Send()
                    }
                    .tint(Link.IsSending ? .green : .accentColor)
                    .sensoryFeedback(.success, trigger: Link.SendCount)
                }
                Section("My Places")
                {
                    if Store.Custom.isEmpty
                    {
                        Text("Nothing here yet. Tap Add to enter a place, or edit a built-in place to make your own copy of it.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Mine)
                    {
                        Place in
                        PlaceListRow(Place: Place, Note: Place.ReplacesKey == nil ? nil : "Edited copy of a built-in place",
                                     Here: Compass.Location, MaxDistance: Settings.MaxDistance, Unit: Settings.Unit,
                                     OnEdit: { Editing = PlaceDraft(Editing: Place) },
                                     OnDelete: { Store.Delete(IDs: [Place.id]) },
                                     OnToggleVisible: { Store.SetVisible(Place, Place.IsVisible == false) })
                    }
                    .onDelete { Remove($0, From: Mine) }
                }
                Section("Built-in Places")
                {
                    ForEach(BuiltIn)
                    {
                        Place in
                        PlaceListRow(Place: Place, Note: nil,
                                     Here: Compass.Location, MaxDistance: Settings.MaxDistance, Unit: Settings.Unit,
                                     OnEdit: { Editing = PlaceDraft(Editing: Place) },
                                     OnDelete: { Store.Delete(IDs: [Place.id]) },
                                     OnToggleVisible: { Store.SetVisible(Place, Place.IsVisible == false) })
                    }
                    .onDelete { Remove($0, From: BuiltIn) }
                }
                if Store.HasBuiltInChanges
                {
                    Section
                    {
                        Button("Reset Built-In Locations", systemImage: "arrow.uturn.backward", role: .destructive)
                        {
                            ConfirmingReset = true
                        }
                    }
                    footer:
                    {
                        Text("Brings back deleted and hidden built-in places and discards your edits to them. Places you added yourself are kept.")
                    }
                }
            }
            .searchable(text: $SearchText, prompt: "Search places")
            .confirmationDialog("Reset the built-in locations?", isPresented: $ConfirmingReset, titleVisibility: .visible)
            {
                Button("Reset Built-In Locations", role: .destructive)
                {
                    Store.ResetBuiltIns()
                }
            }
            message:
            {
                Text("Deleted and hidden built-in places come back and your edits to them are discarded.")
            }
            .navigationTitle("Places")
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction)
                {
                    Button("Add", systemImage: "plus")
                    {
                        Editing = PlaceDraft()
                    }
                }
            }
            .sheet(item: $Editing)
            {
                Draft in
                PlaceEditor(Draft: Draft, Compass: Compass, OnSave:
                {
                    Place in
                    Store.Save(Place)
                },
                OnDelete: Draft.IsNew ? nil :
                {
                    if let ID = Draft.PlaceID
                    {
                        Store.Delete(IDs: [ID])
                    }
                },
                IsBuiltIn: Draft.PlaceID.map { NorthernCaliforniaData.BuiltInIDs.contains($0) } ?? false)
            }
        }
    }
}

///A row of the list. Tap to edit; tap the eye to show or hide the place on the radar; swipe or long-press to delete.
struct PlaceListRow: View
{
    let Place: POI
    ///Small extra text under the place, or `nil`.
    let Note: String?
    let Here: CLLocation?
    let MaxDistance: Double
    let Unit: DistanceUnit
    let OnEdit: () -> Void
    let OnDelete: () -> Void
    ///Shows the place on the radar if it is hidden, and hides it if it is shown.
    let OnToggleVisible: () -> Void

    var ToggleTitle: String
    {
        Place.IsVisible ? "Hide from Radar" : "Show on Radar"
    }

    var body: some View
    {
        HStack
        {
            Button(action: OnEdit)
            {
                PlaceRow(Place: Place, Here: Here, MaxDistance: MaxDistance, Unit: Unit, Note: Note)
            }
            .tint(.primary)
            Spacer()
            //Borderless so this and the edit button are separate targets in one row.
            Button(ToggleTitle, systemImage: Place.IsVisible ? "eye" : "eye.slash", action: OnToggleVisible)
                .labelStyle(.iconOnly)
                .foregroundStyle(Place.IsVisible ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.borderless)
        .swipeActions(edge: .trailing, allowsFullSwipe: true)
        {
            Button("Delete", systemImage: "trash", role: .destructive, action: OnDelete)
        }
        .swipeActions(edge: .leading)
        {
            Button(ToggleTitle, systemImage: Place.IsVisible ? "eye.slash" : "eye", action: OnToggleVisible)
                .tint(.indigo)
        }
        .contextMenu
        {
            Button(ToggleTitle, systemImage: Place.IsVisible ? "eye.slash" : "eye", action: OnToggleVisible)
            Button("Delete", systemImage: "trash", role: .destructive, action: OnDelete)
        }
    }
}

///One line of the list: the type's marker, the name, and the coordinate.
struct PlaceRow: View
{
    let Place: POI
    ///The latest location fix, to show how far the place is (and so whether the radar can show it); `nil` without one.
    var Here: CLLocation? = nil
    ///The radar's maximum range in meters; farther places are not shown.
    var MaxDistance: Double = 800_000
    var Unit: DistanceUnit = .Metric
    var Note: String? = nil

    ///How far the place is from here, e.g. "231 km away", or `nil` without a fix.
    var DistanceText: String?
    {
        guard let Here else
        {
            return nil
        }
        let Meters = Here.distance(from: CLLocation(latitude: Place.Latitude, longitude: Place.Longitude))
        let Beyond = Meters > MaxDistance ? " (beyond the \(DistanceFormat.Short(Meters: MaxDistance, Unit: Unit)) radar range)" : ""
        return DistanceFormat.Short(Meters: Meters, Unit: Unit) + " away" + Beyond
    }

    var body: some View
    {
        HStack
        {
            POIMarker(Kind: Place.Kind, Size: 28)
                .opacity(Place.IsVisible ? 1 : 0.4)
            VStack(alignment: .leading)
            {
                Text(Place.Name)
                if let Description = Place.Description, Description.isEmpty == false
                {
                    Text(Description)
                        .font(.caption)
                }
                Text("\(Place.Latitude.formatted(.number.precision(.fractionLength(4)))), \(Place.Longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let DistanceText
                {
                    Text(DistanceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if Place.IsVisible == false
                {
                    Text("Hidden from the radar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let Note
                {
                    Text(Note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
