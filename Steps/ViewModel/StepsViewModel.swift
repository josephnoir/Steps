//
//  StepsViewModel.swift
//  Steps
//
//  Created by Brittany Rima on 12/14/22.
//

import SwiftUI
import HealthKit
import PhotosUI
import CoreTransferable

class StepsViewModel: ObservableObject {
    var healthStore: HKHealthStore?
    var query: HKStatisticsCollectionQuery?
    @AppStorage("stepCount", store: UserDefaults(suiteName: "group.com.BrittanyRima.Steps")) var stepCount: Int = 0

    @Published var steps: [Step] = []
    @Published var goal: Int = 10000 {
        didSet {
            UserDefaults.standard.set(goal, forKey: Constants.goalKey)
        }
    }

    init() {
        self.goal = UserDefaults.standard.integer(forKey: Constants.goalKey)

        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }

    var currentSteps: Int {
        steps.last?.count ?? 0
    }

    var soccerFieldsWalkedString: String {
        let numOfFields = currentSteps / 144 // For every 144 Steps you've walked about 1 soccer field.

        if numOfFields > 1 {
            return String(format: Constants.walkedCustomSoccerFieldToday, numOfFields)
        } else if numOfFields == 0 {
            return Constants.walkedFullSoccerFieldToday
        } else {
            return Constants.walkedOneSoccerFieldToday
        }
    }

    var checkPointOneReached: Bool {
        Double(currentSteps) >= (Double(goal) * 0.25)
    }

    var checkPointTwoReached: Bool {
        Double(currentSteps) >= (Double(goal) * 0.5)
    }

    var checkPointThreeReached: Bool {
        Double(currentSteps) >= (Double(goal) * 0.75)
    }

    var checkPointFourReached: Bool {
        currentSteps >= goal
    }

    func calculateSteps(completion: @escaping (HKStatisticsCollection?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let anchorDate = Date.sundayAt12AM()
        let daily = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        query = HKStatisticsCollectionQuery(quantityType: stepType,
                                    quantitySamplePredicate: predicate,
                                    options: .cumulativeSum,
                                    anchorDate: anchorDate,
                                    intervalComponents: daily)
        query!.initialResultsHandler = { query, statsCollection, error in
            completion(statsCollection)
        }

        if let healthStore = healthStore, let query = self.query {
            healthStore.execute(query)
        }
    }

    func updateUIFromStats(_ statsCollection: HKStatisticsCollection) {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()

        statsCollection.enumerateStatistics(from: startDate, to: endDate) { stats, stop in
            let count = stats.sumQuantity()?.doubleValue(for: .count())
            let step = Step(count: Int(count ?? 0), date: stats.startDate)
            
            DispatchQueue.main.async {
                self.steps.append(step)
                self.stepCount = self.steps.last?.count ?? 0
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        guard let healthStore = self.healthStore else { return  completion(false) }

        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
            completion(success)
        }
    }
    
    // MARK: - Background Image
    
    @Published var showBackgroundImageAlert = false
    
    enum BackgroundImageState {
        case empty
        case loading(Progress)
        case success(Image)
        case failure(Error)
    }
    
    @Published private(set) var backgroundImageState: BackgroundImageState = .empty
    
    @Published var backgroundImageSelection: PhotosPickerItem? = nil {
        didSet {
            if let backgroundImageSelection {
                let progress = loadTransferable(from: backgroundImageSelection)
                backgroundImageState = .loading(progress)
            } else {
                backgroundImageState = .empty
            }
        }
    }
    
    enum TransferError: Error {
        case importFailed
    }
    
    struct BackgroundImage: Transferable {
        let image: Image
        
        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(importedContentType: .image) { data in
                guard let uiImage = UIImage(data: data) else {
                    throw TransferError.importFailed
                }
                let image = Image(uiImage: uiImage)
                return BackgroundImage(image: image)
            }
        }
    }
    
    private func loadTransferable(from backgroundImageSelection: PhotosPickerItem) -> Progress {
        return backgroundImageSelection.loadTransferable(type: BackgroundImage.self) { result in
            DispatchQueue.main.async {
                guard backgroundImageSelection == self.backgroundImageSelection else {
                    print("Failed to get the selected item.")
                    return
                }
                switch result {
                case .success(let backgroundImage?):
                    self.backgroundImageState = .success(backgroundImage.image)
                case .success(nil):
                    self.backgroundImageState = .empty
                case .failure(let error):
                    self.showBackgroundImageAlert = true
                    self.backgroundImageState = .failure(error)
                }
            }
        }
    }
}
