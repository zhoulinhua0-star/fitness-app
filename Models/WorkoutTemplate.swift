//
//  WorkoutTemplate.swift
//  FitnessApp
//
//  A reusable, named workout "recipe" (e.g. 推日 / 拉日 / 腿日) that lives in the
//  template library, independent of any weekday. Users build templates once and
//  copy them into any day's schedule — the same flow as Strong's "Set up template".
//
//  TemplateExercise is deliberately a separate @Model from `Exercise` so the two
//  never share a SwiftData relationship (which would let adding an exercise to a
//  template silently pull it out of a WorkoutDay). Copying converts one to the other.
//

import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var name: String
    var createdAt: Date

    // Cascade so deleting a template also removes its exercises.
    @Relationship(deleteRule: .cascade)
    var exercises: [TemplateExercise]

    init(name: String, createdAt: Date = .now, exercises: [TemplateExercise] = []) {
        self.name = name
        self.createdAt = createdAt
        self.exercises = exercises
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
    var sortedExercises: [TemplateExercise] { exercises.sorted { $0.order < $1.order } }
}

@Model
final class TemplateExercise {
    var name: String
    var sets: Int
    var reps: Int
    var order: Int

    init(name: String, sets: Int, reps: Int, order: Int = 0) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.order = order
    }
}
