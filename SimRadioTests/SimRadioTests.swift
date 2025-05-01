//
//  SimRadioTests.swift
//  SimRadioTests
//
//  Created by Alexey Vorobyov on 30.01.2025.
//

import Foundation
@testable import SimRadio
import Testing

struct SimRadioTests {
    @Test func testMakePlaylist() async throws {
        let series = try JSONDecoder().decode(SimRadioDTO.GameSeries.self, from: radioJson.data(using: .utf8)!)

        let playlistBuilder = PlaylistBuilder(
            baseUrl: URL(string: "/")!,
            gameSeriesSharedFiles: series.gameSeriesShared.fileGroups,
            station: series.stations.first!
        )

        DRand48.srand48(100)
        let playlist = try await playlistBuilder.makePlaylist(duration: 3 * 60 * 60)
        print("##")
        print(playlist.description)
        print("##")
        #expect(playlist.description == playlistForSeed100)
    }
}

// swiftlint:disable line_length file_length
let playlistForSeed100 = #"""
(0.0..6.67): id/id_01.m4a
(6.67..256.21): radio_01_class_rock/all_the_things_she_said.m4a
  (246.69..248.79): to_ad/to_ad_02.m4a
(256.21..288.46): adverts/mono_ad009_prop_43.m4a
(288.46..617.63): radio_01_class_rock/baker_street.m4a
  (298.13..304.98): intro/baker_street_02.m4a
(617.63..827.83): radio_01_class_rock/big_log.m4a
  (623.86..626.44): intro/big_log_01.m4a
  (818.09..821.63): to_news/to_news_02.m4a
(827.83..931.1): news/mono_news_03.m4a
(931.1..938.46): id/id_05.m4a
(938.46..1204.99): radio_01_class_rock/black_velvet.m4a
(1204.99..1228.2): mono_solo/mono_solo_02.m4a
(1228.2..1348.39): news/mono_news_05.m4a
(1348.39..1354.87): id/id_04.m4a
(1354.87..1604.41): radio_01_class_rock/all_the_things_she_said.m4a
(1604.41..1822.07): radio_01_class_rock/burning_heart.m4a
  (1610.74..1617.23): intro/burning_heart_01.m4a
(1822.07..2151.24): radio_01_class_rock/baker_street.m4a
(2151.24..2400.78): radio_01_class_rock/all_the_things_she_said.m4a
(2400.78..2423.71): mono_solo/heists_obh_briefcase_close_mt_thud.m4a
(2423.71..2547.76): news/mono_news_09.m4a
(2547.76..2552.94): id/id_02.m4a
(2552.94..2763.14): radio_01_class_rock/big_log.m4a
  (2559.17..2561.75): intro/big_log_01.m4a
(2763.14..2787.76): mono_solo/mono_solo_03.m4a
(2787.76..2936.17): news/mono_news_01.m4a
(2936.17..2943.53): id/id_05.m4a
(2943.53..3272.7): radio_01_class_rock/baker_street.m4a
  (2953.3..2956.63): general/general_05.m4a
  (3260.33..3262.9): to_ad/to_ad_03.m4a
(3272.7..3321.02): adverts/ad082_alcoholia.m4a
(3321.02..3587.55): radio_01_class_rock/black_velvet.m4a
  (3328.85..3334.2): intro/black_velvet_01.m4a
(3587.55..3611.69): mono_solo/mono_solo_04.m4a
(3611.69..3861.23): radio_01_class_rock/all_the_things_she_said.m4a
(3861.23..4190.4): radio_01_class_rock/baker_street.m4a
  (4174.75..4180.7): general/general_02.m4a
(4190.4..4207.67): mono_solo/mono_solo_01.m4a
(4207.67..4357.51): news/mono_news_02.m4a
(4357.51..4363.99): id/id_04.m4a
(4363.99..4630.52): radio_01_class_rock/black_velvet.m4a
(4630.52..4848.18): radio_01_class_rock/burning_heart.m4a
(4848.18..4871.39): mono_solo/mono_solo_02.m4a
(4871.39..4973.74): news/mono_news_10.m4a
(4973.74..5183.94): radio_01_class_rock/big_log.m4a
  (5175.16..5177.71): to_news/to_news_03.m4a
(5183.94..5330.43): news/mono_news_04.m4a
(5330.43..5579.97): radio_01_class_rock/all_the_things_she_said.m4a
(5579.97..5909.14): radio_01_class_rock/baker_street.m4a
  (5589.81..5591.21): general/general_04.m4a
  (5896.23..5899.36): to_ad/to_ad_01.m4a
(5909.14..5936.32): adverts/mono_ad002_righteous_slaughter_nuke.m4a
(5936.32..6202.85): radio_01_class_rock/black_velvet.m4a
  (5944.17..5948.99): intro/black_velvet_02.m4a
(6202.85..6452.39): radio_01_class_rock/all_the_things_she_said.m4a
  (6442.87..6444.97): to_ad/to_ad_02.m4a
(6452.39..6488.68): adverts/mono_ad006_desert_tourism.m4a
(6488.68..6698.88): radio_01_class_rock/big_log.m4a
  (6689.3..6692.67): general/general_03.m4a
(6698.88..6721.81): mono_solo/heists_obh_briefcase_close_mt_thud.m4a
(6721.81..6939.47): radio_01_class_rock/burning_heart.m4a
  (6728.14..6734.63): intro/burning_heart_01.m4a
(6939.47..6964.08): mono_solo/mono_solo_03.m4a
(6964.08..7062.9): news/mono_news_07.m4a
(7062.9..7068.1): id/id_03.m4a
(7068.1..7334.63): radio_01_class_rock/black_velvet.m4a
(7334.63..7351.9): mono_solo/mono_solo_01.m4a
(7351.9..7455.17): news/mono_news_03.m4a
(7455.17..7461.84): id/id_01.m4a
(7461.84..7791.01): radio_01_class_rock/baker_street.m4a
(7791.01..7815.15): mono_solo/mono_solo_04.m4a
(7815.15..8025.35): radio_01_class_rock/big_log.m4a
  (8016.01..8019.14): to_ad/to_ad_01.m4a
(8025.35..8048.19): adverts/mono_ad008_up_n_atom.m4a
(8048.19..8314.72): radio_01_class_rock/black_velvet.m4a
  (8304.69..8306.79): to_ad/to_ad_02.m4a
(8314.72..8369.2): adverts/mono_ad003_righteous_slaughter_russian.m4a
(8369.2..8698.37): radio_01_class_rock/baker_street.m4a
  (8685.07..8688.61): to_news/to_news_02.m4a
(8698.37..8838.48): news/mono_news_06.m4a
(8838.48..8845.84): id/id_05.m4a
(8845.84..9063.5): radio_01_class_rock/burning_heart.m4a
  (9054.48..9057.05): to_ad/to_ad_03.m4a
(9063.5..9111.82): adverts/ad082_alcoholia.m4a
(9111.82..9378.35): radio_01_class_rock/black_velvet.m4a
  (9364.59..9370.54): general/general_02.m4a
(9378.35..9401.56): mono_solo/mono_solo_02.m4a
(9401.56..9730.73): radio_01_class_rock/baker_street.m4a
  (9411.32..9415.08): general/general_01.m4a
  (9718.38..9720.93): to_news/to_news_03.m4a
(9730.73..9860.86): news/mono_news_08.m4a
(9860.86..10071.06): radio_01_class_rock/big_log.m4a
  (9867.07..9870.4): general/general_05.m4a
  (10062.72..10064.82): to_ad/to_ad_02.m4a
(10071.06..10101.52): adverts/mono_ad001_life_invader.m4a
(10101.52..10368.05): radio_01_class_rock/black_velvet.m4a
  (10109.38..10114.2): intro/black_velvet_02.m4a
  (10356.62..10360.16): to_news/to_news_02.m4a
(10368.05..10517.89): news/mono_news_02.m4a
(10517.89..10735.55): radio_01_class_rock/burning_heart.m4a
  (10524.24..10530.43): intro/burning_heart_02.m4a
(10735.55..10758.48): mono_solo/heists_obh_briefcase_close_mt_thud.m4a
(10758.48..10860.83): news/mono_news_10.m4a

"""#

let radioJson = #"""
{
  "info": {
    "title": "GTA V Radio",
    "logo": "gta_v.png"
  },
  "common": {
    "fileGroups": [
      {
        "tag": "adverts",
        "files": [
          { "path": "common/adverts/ad082_alcoholia.m4a", "duration": 48.32 },
          { "path": "common/adverts/mono_ad001_life_invader.m4a", "duration": 31.05, "audibleDuration": 30.462 },
          { "path": "common/adverts/mono_ad002_righteous_slaughter_nuke.m4a", "duration": 27.93, "audibleDuration": 27.177 },
          { "path": "common/adverts/mono_ad003_righteous_slaughter_russian.m4a", "duration": 55.09, "audibleDuration": 54.48 },
          { "path": "common/adverts/mono_ad004_righteous_slaughter_levels.m4a", "duration": 48.34, "audibleDuration": 47.63 },
          { "path": "common/adverts/mono_ad005_sa_tourism_board.m4a", "duration": 51.73 },
          { "path": "common/adverts/mono_ad006_desert_tourism.m4a", "duration": 37.03, "audibleDuration": 36.286 },
          { "path": "common/adverts/mono_ad007_sa_water_power.m4a", "duration": 35.04 },
          { "path": "common/adverts/mono_ad008_up_n_atom.m4a", "duration": 22.84 },
          { "path": "common/adverts/mono_ad009_prop_43.m4a", "duration": 32.25}
        ]
      },
      {
        "tag": "news",
        "files": [
          { "path": "common/news/mono_news_01.m4a", "duration": 150.21, "audibleDuration": 148.41 },
          { "path": "common/news/mono_news_02.m4a", "duration": 151.38, "audibleDuration": 149.84 },
          { "path": "common/news/mono_news_03.m4a", "duration": 104.79, "audibleDuration": 103.27 },
          { "path": "common/news/mono_news_04.m4a", "duration": 148.35, "audibleDuration": 146.49 },
          { "path": "common/news/mono_news_05.m4a", "duration": 121.83, "audibleDuration": 120.19 },
          { "path": "common/news/mono_news_06.m4a", "duration": 141.74, "audibleDuration": 140.11 },
          { "path": "common/news/mono_news_07.m4a", "duration": 100.26, "audibleDuration": 98.814 },
          { "path": "common/news/mono_news_08.m4a", "duration": 131.75, "audibleDuration": 130.13 },
          { "path": "common/news/mono_news_09.m4a", "duration": 125.59, "audibleDuration": 124.05 },
          { "path": "common/news/mono_news_10.m4a", "duration": 104.22, "audibleDuration": 102.35 }
        ]
      }
    ]
  },
  "stations": [
    {
      "tag": "radio_01_class_rock",
      "info": {
        "title": "Los Santos Rock Radio",
        "genre": "Classic rock, soft rock, pop rock",
        "logo": "radio_01_class_rock.png",
        "dj": "Kenny Loggins"
      },
      "fileGroups": [
        {
          "tag": "track",
          "files": [
            {
              "path": "all_the_things_she_said.m4a",
              "duration": 249.54,
              "attaches": {
                "files": [
                  { "path": "intro/all_the_things_she_said_01.m4a", "duration": 3.94, "audibleDuration": 3.5613 },
                  { "path": "intro/all_the_things_she_said_02.m4a", "duration": 5.11 }
                ]
              }
            },
            {
              "path": "baker_street.m4a",
              "duration": 329.17,
              "attaches": {
                "files": [ { "path": "intro/baker_street_01.m4a", "duration": 3.63 }, { "path": "intro/baker_street_02.m4a", "duration": 6.85 } ]
              }
            },
            {
              "path": "big_log.m4a",
              "duration": 211.03,
              "audibleDuration": 210.2,
              "attaches": {
                "files": [ { "path": "intro/big_log_01.m4a", "duration": 2.58 }, { "path": "intro/big_log_02.m4a", "duration": 6.02 } ]
              }
            },
            {
              "path": "black_velvet.m4a",
              "duration": 266.88,
              "audibleDuration": 266.53,
              "attaches": {
                "files": [ { "path": "intro/black_velvet_01.m4a", "duration": 5.35 }, { "path": "intro/black_velvet_02.m4a", "duration": 4.82} ]
              }
            },
            {
              "path": "burning_heart.m4a",
              "duration": 218.35,
              "audibleDuration": 217.66,
              "attaches": {
                "files": [ { "path": "intro/burning_heart_01.m4a", "duration": 6.49 }, { "path": "intro/burning_heart_02.m4a", "duration": 6.19 } ]
              }
            }
          ]
        },
        {
          "tag": "general",
          "files": [
            { "path": "general/general_01.m4a", "duration": 4.08, "audibleDuration": 3.7533 },
            { "path": "general/general_02.m4a", "duration": 5.95 },
            { "path": "general/general_03.m4a", "duration": 3.37 },
            { "path": "general/general_04.m4a", "duration": 1.4 },
            { "path": "general/general_05.m4a", "duration": 3.33 }
          ]
        },
        {
          "tag": "id",
          "files": [
            { "path": "id/id_01.m4a", "duration": 7.27, "audibleDuration": 6.67 },
            { "path": "id/id_02.m4a", "duration": 5.57, "audibleDuration": 5.1826 },
            { "path": "id/id_03.m4a", "duration": 6.27, "audibleDuration": 5.2 },
            { "path": "id/id_04.m4a", "duration": 7.61, "audibleDuration": 6.48 },
            { "path": "id/id_05.m4a", "duration": 8.49, "audibleDuration": 7.3586 },
          ]
        },
        {
          "tag": "mono_solo",
          "files": [
            { "path": "mono_solo/heists_obh_briefcase_close_mt_thud.m4a", "duration": 24.25, "audibleDuration": 22.93 },
            { "path": "mono_solo/mono_solo_01.m4a", "duration": 18.57, "audibleDuration": 17.278 },
            { "path": "mono_solo/mono_solo_02.m4a", "duration": 24.37, "audibleDuration": 23.209 },
            { "path": "mono_solo/mono_solo_03.m4a", "duration": 26.0, "audibleDuration": 24.617 },
            { "path": "mono_solo/mono_solo_04.m4a", "duration": 25.62, "audibleDuration": 24.14 }
          ]
        },
        {
          "tag": "time_evening",
          "files": [
            { "path": "time_evening/evening_01.m4a", "duration": 3.97, "audibleDuration": 3.66 },
            { "path": "time_evening/evening_02.m4a", "duration": 2.31, "audibleDuration": 1.7906 },
            { "path": "time_evening/evening_03.m4a", "duration": 3.19 }
          ]
        },
        {
          "tag": "time_morning",
          "files": [
            { "path": "time_morning/morning_01.m4a", "duration": 5.17 },
            { "path": "time_morning/morning_02.m4a", "duration": 4.48 },
            { "path": "time_morning/morning_03.m4a", "duration": 3.79 },
          ]
        },
        {
          "tag": "to_adverts",
          "files": [
            { "path": "to_ad/to_ad_01.m4a", "duration": 3.49, "audibleDuration": 3.1346 },
            { "path": "to_ad/to_ad_02.m4a", "duration": 2.1 },
            { "path": "to_ad/to_ad_03.m4a", "duration": 2.57 },
          ]
        },
        {
          "tag": "to_news",
          "files": [ 
            { "path": "to_news/to_news_01.m4a", "duration": 4.06},
            { "path": "to_news/to_news_02.m4a", "duration": 3.54 },
            { "path": "to_news/to_news_03.m4a", "duration": 2.55 },
          ]
        }
      ],
      "playlist": {
        "firstFragment": { "fragmentTag": "id" },
        "fragments": [
          {
            "tag": "id",
            "src": { "type": "group", "groupTag": "id" },
            "nextFragment": [
              { "fragmentTag": "track" }
            ]
          },
          {
            "tag": "track",
            "src": { "type": "group", "groupTag": "track" },
            "nextFragment": [
              { "fragmentTag": "adverts", "probability": 0.357 },
              { "fragmentTag": "monoSolo", "probability": 0.286 },
              { "fragmentTag": "news", "probability": 0.143 },
              { "fragmentTag": "track" }
            ],
            "mixins": {
              "pos": [
                { "tag": "begin", "relativeOffset": 0.03 },
                { "tag": "end", "relativeOffset": 0.97 }
              ],
              "mix": [
                {
                  "tag": "toNews",
                  "src": { "type": "group", "groupTag": "to_news" },
                  "condition": { "type": "nextFragment", "fragmentTag": "news" },
                  "posVariant": [ { "posTag": "end" } ]
                },
                {
                  "tag": "toAdverts",
                  "src": { "type": "group", "groupTag": "to_adverts" },
                  "condition": { "type": "nextFragment", "fragmentTag": "adverts" },
                  "posVariant": [ { "posTag": "end" } ]
                },
                {
                  "tag": "general",
                  "src": { "type": "group", "groupTag": "general" },
                  "condition": { "type": "random", "probability": 0.333 },
                  "posVariant": [ { "posTag": "end" }, { "posTag": "begin" } ]
                },
                {
                  "tag": "intro",
                  "src": { "type": "attach" },
                  "condition": { "type": "random", "probability": 0.333 },
                  "posVariant": [ { "posTag": "begin" }, { "posTag": "end" } ]
                },
                {
                  "tag": "morning",
                  "src": { "type": "group","groupTag": "time_morning" },
                  "condition": {
                    "type": "groupAnd",
                    "condition": [ 
                        { "type": "random", "probability": 0.333 },
                        { "type": "timeInterval", "from": "5:00", "to": "11:00"}
                    ]
                  },
                  "posVariant": [ { "posTag": "end" }, { "posTag": "begin" } ]
                },
                {
                  "tag": "evening",
                  "src": { "type": "group", "groupTag": "time_evening" },
                  "condition": {
                    "type": "groupAnd",
                    "condition": [
                      { "type": "random", "probability": 0.333 },
                      { "type": "timeInterval", "from": "18:00", "to": "24:00" }
                    ]
                  },
                  "posVariant": [ { "posTag": "end" }, { "posTag": "begin" } ]
                }
              ]
            }
          },
          {
            "tag": "monoSolo",
            "src": { "type": "group", "groupTag": "mono_solo"},
            "nextFragment": [
              { "fragmentTag": "news", "probability": 0.4 },
              { "fragmentTag": "track" }
            ]
          },
          {
            "tag": "news",
            "src": { "type": "group","groupTag": "news" },
            "nextFragment": [
              { "fragmentTag": "id", "probability": 0.667 },
              { "fragmentTag": "track" }
            ]
          },
          {
            "tag": "adverts",
            "src": { "type": "group", "groupTag": "adverts" },
            "nextFragment": [ 
                { "fragmentTag": "track" }
            ]
          }
        ]
      }
    }
  ] 
}
"""#
// swiftlint:enable line_length file_length
