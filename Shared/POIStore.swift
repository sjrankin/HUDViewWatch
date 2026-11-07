//
//  POIStore.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/4/26.
//

import Foundation
import Observation

///The user's own points of interest, kept in a file. The iPhone is where they are entered and edited; the watch keeps the copy
///the iPhone sent (see `WatchLink`). The built-in Northern California places are not stored here.
@MainActor
@Observable
final class POIStore
{
    ///The user's places, in the order they were added.
    private(set) var Custom: [POI] = []

    ///When the places last changed on this device, for the status display. `nil` until the first change.
    private(set) var LastChange: Date? = nil

    ///The `Key`s of built-in places the user deleted. They are kept in UserDefaults and never shown again (until restored).
    ///A built-in place the user edited is not listed here: it is hidden because its copy says it replaces it.
    private(set) var Deleted: Set<String> = []

    ///The `Key`s of built-in places the user hid from the radar. They stay in the lists. A user's own place keeps its own `IsVisible`.
    private(set) var HiddenBuiltIns: Set<String> = []

    @ObservationIgnored
    private let FileURL: URL
    @ObservationIgnored
    private let Defaults: UserDefaults

    nonisolated static let DeletedKey = "DeletedBuiltInPlaces"
    nonisolated static let HiddenKey = "HiddenBuiltInPlaces"

    ///- Parameter FileURL: Where the user's places are kept.
    ///- Parameter Defaults: Where the list of deleted built-in places is kept. Tests pass their own suite.
    init(FileURL: URL = POIStore.DefaultFileURL, Defaults: UserDefaults = .standard)
    {
        self.FileURL = FileURL
        self.Defaults = Defaults
        Deleted = Set(Defaults.stringArray(forKey: POIStore.DeletedKey) ?? [])
        HiddenBuiltIns = Set(Defaults.stringArray(forKey: POIStore.HiddenKey) ?? [])
        Load()
    }

    nonisolated static var DefaultFileURL: URL
    {
        URL.applicationSupportDirectory.appending(path: "CustomPOIs.json")
    }

    ///The keys of the built-in places the user has edited; each has a copy in `Custom` that stands in for it.
    private var ReplacedKeys: Set<String>
    {
        Set(Custom.compactMap(\.ReplacesKey))
    }

    ///The built-in places the user can see: not deleted and not replaced by an edited copy.
    var BuiltIn: [POI]
    {
        let Replaced = ReplacedKeys
        let Hidden = HiddenBuiltIns
        return NorthernCaliforniaData.AllPOIs
            .filter { Deleted.contains($0.Key) == false && Replaced.contains($0.Key) == false }
            .map
            {
                var Place = $0
                Place.IsVisible = Hidden.contains(Place.Key) == false
                return Place
            }
    }

    ///Every place in the lists: the built-in places that are still in use and the user's own, hidden or not.
    var All: [POI]
    {
        BuiltIn + Custom
    }

    ///The places to plot on the radar: `All` without the ones hidden from it.
    var Visible: [POI]
    {
        All.filter(\.IsVisible)
    }

    ///Shows or hides a place on the radar. A built-in place is not copied; its key goes in or out of `HiddenBuiltIns`.
    func SetVisible(_ Place: POI, _ Show: Bool)
    {
        if let Original = NorthernCaliforniaData.AllPOIs.first(where: { $0.id == Place.id })
        {
            if Show
            {
                HiddenBuiltIns.remove(Original.Key)
            }
            else
            {
                HiddenBuiltIns.insert(Original.Key)
            }
        }
        else if let Index = Custom.firstIndex(where: { $0.id == Place.id })
        {
            Custom[Index].IsVisible = Show
        }
        Changed()
    }

    ///True if the place is one of the built-in places as shipped (not the user's own, and not an edited copy).
    func IsBuiltIn(_ Place: POI) -> Bool
    {
        NorthernCaliforniaData.BuiltInIDs.contains(Place.id)
    }

    ///Adds a place, or replaces the one with the same id. Saving a built-in place does not change it: it makes the user's own copy
    ///(with a new id), which replaces the built-in place everywhere.
    func Save(_ Place: POI)
    {
        var Item = Place
        if let Original = NorthernCaliforniaData.AllPOIs.first(where: { $0.id == Place.id })
        {
            Item.id = UUID()
            Item.ReplacesKey = Original.Key
        }
        else if let Existing = Custom.first(where: { $0.id == Place.id })
        {
            //An edit of an earlier copy keeps standing in for the same built-in place.
            Item.ReplacesKey = Existing.ReplacesKey
        }
        if let Index = Custom.firstIndex(where: { $0.id == Item.id })
        {
            Custom[Index] = Item
        }
        else
        {
            Custom.append(Item)
        }
        Changed()
    }

    ///Deletes places. A built-in place is marked deleted, and stays hidden; so does the original of a deleted edited copy.
    func Delete(IDs: Set<UUID>)
    {
        for ID in IDs
        {
            if let Original = NorthernCaliforniaData.AllPOIs.first(where: { $0.id == ID })
            {
                Deleted.insert(Original.Key)
            }
            else if let Index = Custom.firstIndex(where: { $0.id == ID })
            {
                if let Replaced = Custom[Index].ReplacesKey
                {
                    Deleted.insert(Replaced)
                }
                Custom.remove(at: Index)
            }
        }
        Changed()
    }

    ///True if any built-in place has been deleted, hidden or edited, so there is something for `ResetBuiltIns` to undo.
    var HasBuiltInChanges: Bool
    {
        Deleted.isEmpty == false || HiddenBuiltIns.isEmpty == false || Custom.contains { $0.ReplacesKey != nil }
    }

    ///Undoes every deletion, hiding and edit of the built-in places: deleted ones come back, hidden ones show again and edited
    ///copies are thrown away, so the original places return. The user's own new places are not touched.
    func ResetBuiltIns()
    {
        Deleted = []
        HiddenBuiltIns = []
        Custom.removeAll { $0.ReplacesKey != nil }
        Changed()
    }

    ///Replaces every custom place, the deleted built-in places and the hidden ones (the watch does this with what the iPhone sent).
    func Replace(With Places: [POI], Deleted DeletedKeys: Set<String>? = nil, Hidden HiddenKeys: Set<String>? = nil)
    {
        Custom = Places
        if let DeletedKeys
        {
            Deleted = DeletedKeys
        }
        if let HiddenKeys
        {
            HiddenBuiltIns = HiddenKeys
        }
        Changed()
    }

    private func Changed()
    {
        LastChange = Date()
        Defaults.set(Deleted.sorted(), forKey: POIStore.DeletedKey)
        Defaults.set(HiddenBuiltIns.sorted(), forKey: POIStore.HiddenKey)
        Write()
    }

    // MARK: Files and transfer encoding

    nonisolated static func Encode(_ Places: [POI]) throws -> Data
    {
        let Encoder = JSONEncoder()
        Encoder.outputFormatting = [.sortedKeys]
        return try Encoder.encode(Places)
    }

    nonisolated static func Decode(_ Raw: Data) throws -> [POI]
    {
        try JSONDecoder().decode([POI].self, from: Raw)
    }

    private func Load()
    {
        guard let Raw = try? Data(contentsOf: FileURL),
              let Found = try? POIStore.Decode(Raw) else
        {
            return
        }
        Custom = Found
    }

    private func Write()
    {
        do
        {
            try FileManager.default.createDirectory(at: FileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try POIStore.Encode(Custom).write(to: FileURL, options: .atomic)
        }
        catch
        {
            #if DEBUG
            print("POIStore: cannot save: \(error)")
            #endif
        }
    }
}
