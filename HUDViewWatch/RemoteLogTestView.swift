//
//  RemoteLogTestView.swift
//  HUDViewWatch
//
//  Created by Stuart Rankin on 11/23/26.
//

import SwiftUI
import RemoteLogKit

///A test screen for RemoteLogStore on the Mac: turn sending on, then use the buttons to send each kind of data frame.
struct RemoteLogTestView: View
{
    @Environment(RemoteLogTester.self) private var Tester
    ///The name being edited.
    @State private var NameText = ""

    var body: some View
    {
        @Bindable var Tester = Tester
        NavigationStack
        {
            Form
            {
                Section("Connection")
                {
                    Toggle("Send to RemoteLogStore", isOn: Binding(get: { Tester.IsEnabled }, set: { Tester.SetEnabled($0) }))
                    Text(Tester.State.Description)
                        .foregroundStyle(.secondary)
                    TextField("Name shown on the Mac", text: $NameText)
                        .onSubmit
                        {
                            Tester.Rename(NameText)
                        }
                    Text("Sent so far: \(Tester.SentCount)")
                        .foregroundStyle(.secondary)
                }
                Section("Messages")
                {
                    ForEach(RemoteLogTester.Levels.indices, id: \.self)
                    {
                        Level in
                        Button("Send \(RemoteLogTester.Levels[Level]) Message", systemImage: "text.bubble")
                        {
                            Tester.SendMessage(Level: Level)
                        }
                    }
                    Button("Send Message with Sub-Messages", systemImage: "list.bullet.indent")
                    {
                        Tester.SendMessageWithSubMessages()
                    }
                    Button("Send Message with Unknown Level", systemImage: "questionmark.circle")
                    {
                        Tester.SendMessageWithUnknownLevel()
                    }
                    Button("Send 200 Messages Quickly", systemImage: "bolt")
                    {
                        Tester.SendBurst()
                    }
                    Toggle("Send a Message Every Second", isOn: Binding(get: { Tester.IsStreaming }, set: { Tester.SetStreaming($0) }))
                }
                Section("Prompts")
                {
                    ForEach(RemoteLogTester.PromptKind.allCases, id: \.self)
                    {
                        Kind in
                        Button(Kind.Title, systemImage: "questionmark.bubble")
                        {
                            Tester.SendPrompt(Kind)
                        }
                    }
                    Button("Cancel Last Prompt", systemImage: "xmark.bubble", role: .destructive)
                    {
                        Tester.CancelLastPrompt()
                    }
                    .disabled(Tester.CanCancelPrompt == false)
                }
                Section("Answers from the Mac")
                {
                    if Tester.ReplyLog.isEmpty
                    {
                        Text("None yet. Send a prompt, then tap Run in RemoteLogStore.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Tester.ReplyLog.enumerated(), id: \.offset)
                    {
                        Item in
                        Text(Item.element)
                    }
                    if Tester.ReplyLog.isEmpty == false
                    {
                        Button("Clear", systemImage: "trash")
                        {
                            Tester.ClearReplyLog()
                        }
                    }
                }
            }
            .navigationTitle("Log Test")
            .onAppear
            {
                NameText = Tester.SourceName
            }
        }
    }
}
