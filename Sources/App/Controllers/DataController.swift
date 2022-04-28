//
//  ServerData.swift
//  
//
//  Created by Shawn Long on 4/17/22.
//

import Vapor
import Foundation

enum DataControllerError : Error {
    case FileError(message: String)
    case StorageError(message: String)
}

actor DataController {

    private let data = ServerData()
    private let fileController: FileController
    private let app: Application
    
    //let JSONdata = try surveyEncoder.encode(surveys)
    init(_ app: Application) {
        self.app = app
        self.fileController = FileController(app)
    }

    /**
     This function begins the process of reading survey files and updating the ServerData Actor
     - Returns: Bool representing if reading and storing succeeded
     */
    func initialize() async throws -> Bool {

        // Load Survey 1
        let survey1 = try await fileController.loadSurvey(id: 1, name: "Big Five", group: "I see myself as")
        guard let _ = try? await data.storeSurvey(survey1) else { return false }


        // Load Survey 1 Responses
        let responses = try await fileController.loadResponses(surveyID: 1)
        guard let _ = try? await data.writeSurveyResponses(responses) else { return false }

        // Create Initial Backup
        let _ = try await backup()

        app.logger.info("Successfully Loaded Survey Data and Responses")

        return true
    }

    func getSurveyResponses(uid: String) async throws -> [SurveyResponse] {
        return await data.filterSurveyResponses({$0.uid == uid})
    }

    func getSurveyResponse(id: UUID) async throws -> SurveyResponse? {
        return await data.firstSurveyResponse(where: {$0.id == id})
    }

    func getSurveys() async throws -> [Survey] {
        return await data.filterSurveys({_ in true})
    }

    func createResponse(response: SurveyResponse) async throws -> Bool {
        return try await data.storeSurveyResponse(response)
    }

    func updateResponse(response: SurveyResponse) async throws -> Bool {
        return try await data.storeSurveyResponse(response)
    }

    func deleteResponse(id: UUID) async throws -> Bool {
        app.logger.critical("Data Controller: Atetmpting to delete")
        return await data.deleteSurveyResponse(id: id)
    }

    func backup() async throws -> Bool {
        app.logger.info("Getting list of surveys and responses")
        async let surveys =  data.filterSurveys({ _ in true })
        async let surveyResponses = data.filterSurveyResponses({ _ in true })
        let snapshot = await DataSnapshot(surveys: surveys, surveyResponses: surveyResponses)
        app.logger.info("Snapshot Created")

        if let success = try? await fileController.backup(snapshot: snapshot) {
            return success
        } else { return false}
    }

    func loadBackup() async throws -> Bool {
        if let snapshot = await fileController.getBackup() {

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
            app.logger.info("Loading snapshot from \(dateFormatter.string(from: snapshot.date))")

            if let responseSuccess = try? await data.writeSurveyResponses(snapshot.surveyResponses) {
                if let surveySuccess = try? await data.writeSurveys(snapshot.surveys) {
                    return responseSuccess && surveySuccess
                }
            }
        }
        return false
    }

}

struct MyConfigurationKey: StorageKey {
    typealias Value = DataController
}

extension Application {
    var dataController: DataController? {
        get {
            self.storage[MyConfigurationKey.self]
        }
        set {
            self.storage[MyConfigurationKey.self] = newValue

        }
    }
}
