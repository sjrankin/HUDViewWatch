//
//  RemoteLogTester.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/23/26.
//

import Foundation
import Observation
import RemoteLogKit

///The iPhone app's side of testing RemoteLogStore (the Mac log viewer): sends messages, sub-messages, prompts and cancellations through a
///`RemoteLogClient` and keeps a record of what the Mac sent back, so every feature of the Mac app can be exercised from a button.
///
///The program's ID is saved, so RemoteLogStore recognizes the phone from run to run (and a block on the Mac sticks).
@MainActor
@Observable
final class RemoteLogTester
{
    ///A prompt that was sent, remembered so an answer can be described by its text.
    private struct SentPrompt
    {
        ///The prompt text.
        let Text: String
        ///The answers offered.
        let Responses: [LogResponse]
    }

    ///The labels used for message levels.
    nonisolated static let Levels = ["Debug", "Info", "Warning", "Error"]
    ///Where the program's ID is saved.
    private static let SourceIDKey = "RemoteLogSourceID"
    ///Where the on/off setting is saved.
    private static let EnabledKey = "RemoteLogEnabled"
    ///Where the name is saved.
    private static let NameKey = "RemoteLogSourceName"

    ///Whether the phone is sending to RemoteLogStore.
    private(set) var IsEnabled: Bool
    ///What the connection is doing.
    private(set) var State: RemoteLogConnectionState = .Idle
    ///How many messages and prompts this screen has sent.
    private(set) var SentCount = 0
    ///The answers the Mac sent back, newest last.
    private(set) var ReplyLog: [String] = []
    ///True while the automatic message stream runs.
    private(set) var IsStreaming = false
    ///The name RemoteLogStore shows for the phone. Change it with `Rename`.
    private(set) var SourceName: String

    @ObservationIgnored
    private let Client: RemoteLogClient
    @ObservationIgnored
    private var Prompts: [UUID: SentPrompt] = [:]
    @ObservationIgnored
    private var LastPromptID: UUID? = nil
    @ObservationIgnored
    private var Tasks: [Task<Void, Never>] = []
    @ObservationIgnored
    private var StreamTask: Task<Void, Never>? = nil

    ///Creates the tester and, if it was on last time, starts sending.
    init()
    {
        let Defaults = UserDefaults.standard
        let ID = Defaults.string(forKey: RemoteLogTester.SourceIDKey).flatMap { UUID(uuidString: $0) } ?? UUID()
        Defaults.set(ID.uuidString, forKey: RemoteLogTester.SourceIDKey)
        let Name = Defaults.string(forKey: RemoteLogTester.NameKey) ?? "HUDViewWatch (iPhone)"
        SourceName = Name
        IsEnabled = Defaults.bool(forKey: RemoteLogTester.EnabledKey)
        Client = RemoteLogClient(SourceID: ID, SourceName: Name, Levels: RemoteLogTester.Levels)
        let Replies = Client.Replies
        let States = Client.States
        Tasks.append(Task
        {
            for await Reply in Replies
            {
                self.Received(Reply)
            }
        })
        Tasks.append(Task
        {
            for await NewState in States
            {
                self.State = NewState
            }
        })
        if IsEnabled
        {
            Client.Start()
        }
    }

    ///Turns sending on or off.
    func SetEnabled(_ Enabled: Bool)
    {
        IsEnabled = Enabled
        UserDefaults.standard.set(Enabled, forKey: RemoteLogTester.EnabledKey)
        if Enabled
        {
            Client.Start()
        }
        else
        {
            StopStreaming()
            Client.Stop()
        }
    }

    ///Changes the name RemoteLogStore shows for the phone.
    func Rename(_ NewName: String)
    {
        let Trimmed = NewName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Trimmed.isEmpty == false else
        {
            return
        }
        SourceName = Trimmed
        UserDefaults.standard.set(Trimmed, forKey: RemoteLogTester.NameKey)
        Client.SetSourceName(Trimmed)
    }

    ///A line of text with a number and the time, so each message differs.
    private func Numbered(_ Text: String) -> String
    {
        "\(Text) #\(SentCount + 1) at \(Date().formatted(date: .omitted, time: .standard))"
    }

    // MARK: - Messages

    ///Sends one message at a level (an index into `Levels`).
    func SendMessage(Level: Int)
    {
        Client.Log(Numbered("\(RemoteLogTester.Levels[Level]) message"), Level: Level)
        SentCount += 1
    }

    ///Sends a message with sub-messages, shown as sub-rows in the log.
    func SendMessageWithSubMessages()
    {
        Client.Log(Numbered("Message with details"), Level: 1,
                   SubMessages: ["File: RemoteLogTester.swift", "Line: 123", "Thread: main"])
        SentCount += 1
    }

    ///Sends a message with no level labels' worth of meaning: a level outside the labels, which RemoteLogStore ignores.
    func SendMessageWithUnknownLevel()
    {
        Client.Log(Numbered("Message with a level outside the labels"), Level: 99)
        SentCount += 1
    }

    ///Sends many messages as fast as possible, to see the log keep up.
    func SendBurst(Count: Int = 200)
    {
        for Number in 1 ... Count
        {
            Client.Log("Burst message \(Number) of \(Count)", Level: Number % RemoteLogTester.Levels.count)
        }
        SentCount += Count
    }

    ///Starts or stops sending a message every second.
    func SetStreaming(_ On: Bool)
    {
        StopStreaming()
        guard On else
        {
            return
        }
        IsStreaming = true
        StreamTask = Task
        {
            var Number = 1
            while Task.isCancelled == false
            {
                self.Client.Log("Stream message \(Number)", Level: Number % RemoteLogTester.Levels.count)
                self.SentCount += 1
                Number += 1
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    ///Stops the automatic stream.
    private func StopStreaming()
    {
        StreamTask?.cancel()
        StreamTask = nil
        IsStreaming = false
    }

    // MARK: - Prompts

    ///The kinds of prompt the test screen can send.
    enum PromptKind: CaseIterable
    {
        ///A breakpoint-style prompt with the single answer OK.
        case Breakpoint
        ///A question with three answers.
        case Choice
        ///A prompt that offers no answers.
        case NoAnswers

        ///The button title.
        var Title: String
        {
            switch self
            {
                case .Breakpoint: return "Prompt: Breakpoint (OK)"
                case .Choice: return "Prompt: Yes / No / Maybe"
                case .NoAnswers: return "Prompt: No Answers"
            }
        }
    }

    ///Sends a prompt and remembers it so the answer can be described.
    func SendPrompt(_ Kind: PromptKind)
    {
        let Text: String
        let Responses: [LogResponse]
        switch Kind
        {
            case .Breakpoint:
                Text = "At line 100 in file abc.swift"
                Responses = [LogResponse(Text: "OK")]
            case .Choice:
                Text = Numbered("Should the phone continue?")
                Responses = [LogResponse(Text: "Yes"), LogResponse(Text: "No"), LogResponse(Text: "Maybe")]
            case .NoAnswers:
                Text = "A prompt with no responses"
                Responses = []
        }
        let ID = Client.Prompt(Text, Responses: Responses, Level: 2, SubMessages: ["Sent from the HUDViewWatch test screen"])
        Prompts[ID] = SentPrompt(Text: Text, Responses: Responses)
        LastPromptID = ID
        SentCount += 1
    }

    ///Cancels the prompt sent most recently, if there is one.
    func CancelLastPrompt()
    {
        guard let ID = LastPromptID else
        {
            ReplyLog.append("There is no prompt to cancel.")
            return
        }
        Client.CancelPrompt(ID)
        ReplyLog.append("Cancelled the last prompt.")
        LastPromptID = nil
    }

    ///True when a prompt has been sent that could still be cancelled.
    var CanCancelPrompt: Bool
    {
        LastPromptID != nil
    }

    ///Notes an answer from RemoteLogStore.
    private func Received(_ Reply: PromptReply)
    {
        let Known = Prompts[Reply.PromptID]
        let Chosen = Known?.Responses.first { $0.ID == Reply.ResponseID }?.Text ?? Reply.ResponseID.uuidString
        ReplyLog.append("Answer “\(Chosen)” to “\(Known?.Text ?? Reply.PromptID.uuidString)”")
        if Reply.PromptID == LastPromptID
        {
            LastPromptID = nil
        }
        Prompts[Reply.PromptID] = nil
    }

    ///Clears the record of answers.
    func ClearReplyLog()
    {
        ReplyLog.removeAll()
    }
}
