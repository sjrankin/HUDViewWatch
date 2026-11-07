//
//  POIStoreTests.swift
//  HUDViewWatchTests
//
//  Created by Stuart Rankin on 11/4/26.
//

import Foundation
import Testing
@testable import HUDViewWatch

@MainActor
struct POIStoreTests
{
    ///A store that writes to its own temporary file.
    func MakeStore() -> (POIStore, URL)
    {
        let URL = URL.temporaryDirectory.appending(path: "HUDViewWatchTests-\(UUID().uuidString)").appending(path: "CustomPOIs.json")
        return (POIStore(FileURL: URL, Defaults: UserDefaults(suiteName: "HUDViewWatchTests-\(UUID().uuidString)")!), URL)
    }

    @Test func PlacesSurviveEncodingForTheWatch() throws
    {
        let Place = POI(Name: "札幌 Station", Latitude: 43.0686, Longitude: 141.3508, Kind: .City, Elevation: 17, Population: 1_900_000)
        let Raw = try POIStore.Encode([Place])
        let Back = try POIStore.Decode(Raw)
        #expect(Back == [Place])
    }

    @Test func SaveAddsThenReplacesBySameID()
    {
        let (Store, _) = MakeStore()
        var Place = POI(Name: "Cabin", Latitude: 39.0, Longitude: -120.0, Kind: .Test)
        Store.Save(Place)
        Place.Name = "Big Cabin"
        Store.Save(Place)
        #expect(Store.Custom.count == 1)
        #expect(Store.Custom.first?.Name == "Big Cabin")
    }

    @Test func DeleteRemovesOnlyTheNamedPlaces()
    {
        let (Store, _) = MakeStore()
        let A = POI(Name: "A", Latitude: 1, Longitude: 1, Kind: .Park)
        let B = POI(Name: "B", Latitude: 2, Longitude: 2, Kind: .Lake)
        Store.Save(A)
        Store.Save(B)
        Store.Delete(IDs: [A.id])
        #expect(Store.Custom == [B])
    }

    @Test func PlacesAreSavedToTheFileAndReloaded()
    {
        let (Store, URL) = MakeStore()
        let Place = POI(Name: "Trailhead", Latitude: 38.5, Longitude: -120.5, Kind: .Mountain, Elevation: 2100)
        Store.Save(Place)
        let Reloaded = POIStore(FileURL: URL, Defaults: UserDefaults(suiteName: "HUDViewWatchTests-\(UUID().uuidString)")!)
        #expect(Reloaded.Custom == [Place])
    }

    @Test func ReplaceSwapsTheWholeList()
    {
        let (Store, _) = MakeStore()
        Store.Save(POI(Name: "Old", Latitude: 0, Longitude: 0, Kind: .City))
        let New = [POI(Name: "New 1", Latitude: 5, Longitude: 5, Kind: .Bridge), POI(Name: "New 2", Latitude: 6, Longitude: 6, Kind: .River)]
        Store.Replace(With: New)
        #expect(Store.Custom == New)
    }

    @Test func AllHoldsTheBuiltInPlacesAndTheUsersOwn()
    {
        let (Store, _) = MakeStore()
        let Mine = POI(Name: "Mine", Latitude: 10, Longitude: 10, Kind: .Test)
        Store.Save(Mine)
        #expect(Store.All.contains(Mine))
        #expect(Store.All.count == NorthernCaliforniaData.AllPOIs.count + 1)
    }

    @Test func BadDataIsRefusedNotCrashed()
    {
        #expect(throws: (any Error).self) { try POIStore.Decode(Data("not json".utf8)) }
    }

    // MARK: Built-in places

    @Test func EditingABuiltInPlaceMakesACopyThatReplacesIt()
    {
        let (Store, _) = MakeStore()
        let Original = NorthernCaliforniaData.Cities[0]
        var Edited = Original
        Edited.Name = "The City"
        Store.Save(Edited)
        #expect(Store.Custom.count == 1)
        #expect(Store.Custom[0].id != Original.id)
        #expect(Store.Custom[0].ReplacesKey == Original.Key)
        #expect(Store.All.contains { $0.Name == Original.Name } == false)
        #expect(Store.All.contains { $0.Name == "The City" })
        #expect(Store.All.count == NorthernCaliforniaData.AllPOIs.count)
    }

    @Test func EditingTheCopyAgainKeepsReplacingTheSameBuiltInPlace()
    {
        let (Store, _) = MakeStore()
        var Edited = NorthernCaliforniaData.Cities[0]
        Store.Save(Edited)
        Edited = Store.Custom[0]
        Edited.Name = "Renamed Again"
        Edited.ReplacesKey = nil
        Store.Save(Edited)
        #expect(Store.Custom.count == 1)
        #expect(Store.Custom[0].ReplacesKey == NorthernCaliforniaData.Cities[0].Key)
        #expect(Store.All.count == NorthernCaliforniaData.AllPOIs.count)
    }

    @Test func DeletingABuiltInPlaceHidesItForGood()
    {
        let (Store, _) = MakeStore()
        let Victim = NorthernCaliforniaData.Cities[1]
        Store.Delete(IDs: [Victim.id])
        #expect(Store.All.contains { $0.Key == Victim.Key } == false)
        #expect(Store.Deleted == [Victim.Key])
        #expect(Store.HasBuiltInChanges)
        Store.ResetBuiltIns()
        #expect(Store.All.contains { $0.Key == Victim.Key })
        #expect(Store.HasBuiltInChanges == false)
    }

    @Test func ResettingUndoesEditsAndDeletionsButKeepsTheUsersOwnPlaces()
    {
        let (Store, _) = MakeStore()
        var Edited = NorthernCaliforniaData.Cities[0]
        Edited.Name = "Changed"
        Store.Save(Edited)
        Store.Delete(IDs: [NorthernCaliforniaData.Cities[1].id])
        let Mine = POI(Name: "Mine", Latitude: 10, Longitude: 10, Kind: .Test)
        Store.Save(Mine)
        Store.ResetBuiltIns()
        #expect(Store.Custom == [Mine])
        #expect(Store.Deleted.isEmpty)
        #expect(Store.All.count == NorthernCaliforniaData.AllPOIs.count + 1)
        #expect(Store.All.contains { $0.Key == NorthernCaliforniaData.Cities[0].Key })
        #expect(Store.All.contains { $0.Name == "Changed" } == false)
    }

    @Test func DeletingAnEditedCopyDoesNotBringTheOriginalBack()
    {
        let (Store, _) = MakeStore()
        Store.Save(NorthernCaliforniaData.Cities[2])
        Store.Delete(IDs: [Store.Custom[0].id])
        #expect(Store.Custom.isEmpty)
        #expect(Store.All.contains { $0.Key == NorthernCaliforniaData.Cities[2].Key } == false)
    }

    @Test func DeletedBuiltInPlacesAreRememberedBetweenLaunches()
    {
        let Name = "HUDViewWatchTests-\(UUID().uuidString)"
        let Defaults = UserDefaults(suiteName: Name)!
        let URL = URL.temporaryDirectory.appending(path: Name).appending(path: "CustomPOIs.json")
        let First = POIStore(FileURL: URL, Defaults: Defaults)
        First.Delete(IDs: [NorthernCaliforniaData.Cities[3].id])
        let Second = POIStore(FileURL: URL, Defaults: Defaults)
        #expect(Second.Deleted == [NorthernCaliforniaData.Cities[3].Key])
    }

    @Test func TheWatchCanTakeTheDeletedListFromThePhone()
    {
        let (Store, _) = MakeStore()
        let Key = NorthernCaliforniaData.Cities[4].Key
        Store.Replace(With: [], Deleted: [Key])
        #expect(Store.All.contains { $0.Key == Key } == false)
    }
    // MARK: Visibility on the radar

    @Test func PlacesSavedBeforeVisibilityExistedAreVisible() throws
    {
        let Old = """
        [{"id":"\(UUID().uuidString)","Name":"Old","Latitude":1,"Longitude":2,"Kind":"Park"}]
        """
        let Found = try POIStore.Decode(Data(Old.utf8))
        #expect(Found.first?.IsVisible == true)
    }

    @Test func HiddenStateSurvivesEncodingForTheWatch() throws
    {
        let Place = POI(Name: "Secret", Latitude: 1, Longitude: 2, Kind: .Lake, IsVisible: false)
        let Back = try POIStore.Decode(try POIStore.Encode([Place]))
        #expect(Back.first?.IsVisible == false)
    }

    @Test func HidingAUsersPlaceKeepsItListedButNotPlotted()
    {
        let (Store, _) = MakeStore()
        let Mine = POI(Name: "Cabin", Latitude: 39, Longitude: -120, Kind: .Test)
        Store.Save(Mine)
        Store.SetVisible(Mine, false)
        #expect(Store.Custom.first?.IsVisible == false)
        #expect(Store.All.contains { $0.id == Mine.id })
        #expect(Store.Visible.contains { $0.id == Mine.id } == false)
        Store.SetVisible(Mine, true)
        #expect(Store.Visible.contains { $0.id == Mine.id })
    }

    @Test func HidingABuiltInPlaceDoesNotCopyItAndIsRemembered()
    {
        let Name = "HUDViewWatchTests-\(UUID().uuidString)"
        let Defaults = UserDefaults(suiteName: Name)!
        let URL = URL.temporaryDirectory.appending(path: Name).appending(path: "CustomPOIs.json")
        let First = POIStore(FileURL: URL, Defaults: Defaults)
        let Target = NorthernCaliforniaData.Cities[5]
        First.SetVisible(Target, false)
        #expect(First.Custom.isEmpty)
        #expect(First.BuiltIn.first { $0.Key == Target.Key }?.IsVisible == false)
        #expect(First.Visible.contains { $0.Key == Target.Key } == false)
        #expect(First.All.count == NorthernCaliforniaData.AllPOIs.count)
        let Second = POIStore(FileURL: URL, Defaults: Defaults)
        #expect(Second.Visible.contains { $0.Key == Target.Key } == false)
        Second.SetVisible(Target, true)
        #expect(Second.Visible.contains { $0.Key == Target.Key })
    }

    @Test func ResettingBuiltInsShowsHiddenOnesAgain()
    {
        let (Store, _) = MakeStore()
        let Target = NorthernCaliforniaData.Cities[6]
        Store.SetVisible(Target, false)
        #expect(Store.HasBuiltInChanges)
        Store.ResetBuiltIns()
        #expect(Store.HiddenBuiltIns.isEmpty)
        #expect(Store.Visible.contains { $0.Key == Target.Key })
    }

    @Test func TheWatchCanTakeTheHiddenListFromThePhone()
    {
        let (Store, _) = MakeStore()
        let Key = NorthernCaliforniaData.Cities[7].Key
        Store.Replace(With: [], Hidden: [Key])
        #expect(Store.Visible.contains { $0.Key == Key } == false)
        #expect(Store.All.contains { $0.Key == Key })
    }

    @Test func EditingAHiddenBuiltInPlaceKeepsItHidden()
    {
        let (Store, _) = MakeStore()
        let Target = NorthernCaliforniaData.Cities[8]
        Store.SetVisible(Target, false)
        let Hidden = Store.BuiltIn.first { $0.id == Target.id }!
        Store.Save(PlaceDraft(Editing: Hidden).Make()!)
        #expect(Store.Custom.first?.IsVisible == false)
        #expect(Store.Visible.contains { $0.Key == Target.Key } == false)
    }
}
