import Foundation

/// v0.9.2: ganho médio and worker counts per sector × district.
///
/// Source: GEP-MTSSS Quadros de Pessoal, October 2024, Continente.
///  - **Quadro 110** "GANHO MÉDIO, POR ACTIVIDADE ECONÓMICA, SEGUNDO O DISTRITO"
///  - **Quadro 61**  "TRABALHADORES POR CONTA DE OUTREM, POR ACTIVIDADE ECONÓMICA,
///    SEGUNDO O DISTRITO" — the worker counts, which are what make the thin-cell
///    flag honest rather than a guess.
///
/// Both tables are published in two halves (`Quadro 110` + `Quadro 110 (cont.)`),
/// nine districts each. Every one of the 24 × 18 = 432 cells is populated; there
/// are no suppressed values among the sectors the app ships.
///
/// TENURE IS NOT AVAILABLE HERE, AND IT WOULD NOT CHANGE THE MAP. GEP never
/// crosses district with antiguidade. It would be possible to scale each district
/// by the national sector×tenure multiplier from Quadro 104, but that assumes the
/// tenure premium is identical in every district, and — more to the point — it
/// would cancel out: the same multiplier applied to every district leaves all the
/// ratios, and therefore every colour and every percentage on this map, exactly
/// where they were. It would move only the absolute euro figure. So the map is
/// sector-only and says so.
///
/// Coverage check: the 24 sectors sum to 3,353,982 workers against the published
/// national total of 3,354,136 (the 154 difference is CAE U, which the app has no
/// sector for).
enum DistrictDataset {


    /// Mean gross monthly (ganho médio) per sector, per district.
    static let sectorMean: [Sector: [District: Double]] = [
        .agriculture: [.aveiro: 1216.2, .beja: 1188.57, .braga: 1054.1, .braganca: 1063.04, .casteloBranco: 1149.13, .coimbra: 1215.4, .evora: 1230.86, .faro: 1278.54, .guarda: 1127.36, .leiria: 1199.62, .lisboa: 1209.44, .portalegre: 1183.66, .porto: 1303.44, .santarem: 1228.76, .setubal: 1335.36, .vianaCastelo: 1172.07, .vilaReal: 1137.97, .viseu: 1102.46],
        .extractive: [.aveiro: 1447.59, .beja: 2983.65, .braga: 1250.5, .braganca: 1302.93, .casteloBranco: 1799.34, .coimbra: 1611, .evora: 1583.39, .faro: 1391.33, .guarda: 1360.59, .leiria: 1580.24, .lisboa: 1916.48, .portalegre: 1527.1, .porto: 2282.18, .santarem: 2019.76, .setubal: 1807.08, .vianaCastelo: 1394.11, .vilaReal: 1110.97, .viseu: 1284.58],
        .manufacturing: [.aveiro: 1548.29, .beja: 1360.15, .braga: 1349.69, .braganca: 1254.58, .casteloBranco: 1301.66, .coimbra: 1547.6, .evora: 1539.79, .faro: 1313.75, .guarda: 1393.81, .leiria: 1516.27, .lisboa: 1891.09, .portalegre: 1501.26, .porto: 1407.02, .santarem: 1477.48, .setubal: 2010.68, .vianaCastelo: 1455.3, .vilaReal: 1309.48, .viseu: 1373.47],
        .energy: [.aveiro: 2580.47, .beja: 3138.53, .braga: 2536.96, .braganca: 2906.81, .casteloBranco: 2394.57, .coimbra: 3440.15, .evora: 2648.23, .faro: 2442.48, .guarda: 2910.15, .leiria: 2947.08, .lisboa: 3703.67, .portalegre: 2881.77, .porto: 3504.46, .santarem: 3169.93, .setubal: 2827.56, .vianaCastelo: 2940.77, .vilaReal: 2347.91, .viseu: 2585.93],
        .water: [.aveiro: 1415.72, .beja: 1744.96, .braga: 1348.01, .braganca: 1223.67, .casteloBranco: 1367.09, .coimbra: 1473.29, .evora: 1459.26, .faro: 1432.2, .guarda: 1427.3, .leiria: 1365.99, .lisboa: 1698.31, .portalegre: 1471.52, .porto: 1364.02, .santarem: 1499.47, .setubal: 1655.03, .vianaCastelo: 1371.02, .vilaReal: 1425.9, .viseu: 1210.36],
        .construction: [.aveiro: 1265.63, .beja: 1336.79, .braga: 1327.02, .braganca: 1096.83, .casteloBranco: 1137.49, .coimbra: 1286.85, .evora: 1164.19, .faro: 1263.1, .guarda: 1149.22, .leiria: 1360.36, .lisboa: 1463.83, .portalegre: 1211.41, .porto: 1350.68, .santarem: 1351.8, .setubal: 1263.42, .vianaCastelo: 1245.91, .vilaReal: 1196.08, .viseu: 1245.71],
        .autoTrade: [.aveiro: 1248.76, .beja: 1163.31, .braga: 1208.63, .braganca: 1122.2, .casteloBranco: 1191.34, .coimbra: 1260.75, .evora: 1229.6, .faro: 1269.16, .guarda: 1090.79, .leiria: 1333.79, .lisboa: 1578.13, .portalegre: 1153.12, .porto: 1384.46, .santarem: 1265.81, .setubal: 1284.61, .vianaCastelo: 1151.34, .vilaReal: 1085.18, .viseu: 1202.34],
        .wholesale: [.aveiro: 1478.23, .beja: 1434.69, .braga: 1373.44, .braganca: 1193.59, .casteloBranco: 1349.55, .coimbra: 1394.21, .evora: 1385.87, .faro: 1436.72, .guarda: 1287.32, .leiria: 1459.44, .lisboa: 2340.27, .portalegre: 1424.57, .porto: 1609.72, .santarem: 1408.99, .setubal: 1498.54, .vianaCastelo: 1359.68, .vilaReal: 1189.45, .viseu: 1275.63],
        .retail: [.aveiro: 1283.93, .beja: 1189.34, .braga: 1224.61, .braganca: 1106.17, .casteloBranco: 1175.1, .coimbra: 1221.63, .evora: 1209.65, .faro: 1263.2, .guarda: 1142.25, .leiria: 1243.7, .lisboa: 1468.48, .portalegre: 1166, .porto: 1342.26, .santarem: 1246.57, .setubal: 1287.28, .vianaCastelo: 1196.05, .vilaReal: 1146.85, .viseu: 1172.94],
        .transport: [.aveiro: 1667.64, .beja: 1460.72, .braga: 1459.45, .braganca: 1382.33, .casteloBranco: 1421.62, .coimbra: 1567.98, .evora: 1470.26, .faro: 1535.62, .guarda: 1697.75, .leiria: 1548.2, .lisboa: 2185.39, .portalegre: 1513.72, .porto: 1758.93, .santarem: 1529.59, .setubal: 1824.59, .vianaCastelo: 1568.3, .vilaReal: 1410.02, .viseu: 1608.26],
        .hospitality: [.aveiro: 1035.15, .beja: 1042.54, .braga: 1017.19, .braganca: 948.78, .casteloBranco: 996.84, .coimbra: 1036.01, .evora: 1123.47, .faro: 1221.98, .guarda: 1008.52, .leiria: 1048.4, .lisboa: 1174.69, .portalegre: 1041.13, .porto: 1100.52, .santarem: 1016.49, .setubal: 1058.4, .vianaCastelo: 1018.78, .vilaReal: 1011.1, .viseu: 1049.4],
        .media: [.aveiro: 2165.94, .beja: 1131.66, .braga: 1930.14, .braganca: 1317.85, .casteloBranco: 1375.52, .coimbra: 2045.6, .evora: 1693.73, .faro: 1492.98, .guarda: 1325.92, .leiria: 1514.6, .lisboa: 2387.48, .portalegre: 1221.73, .porto: 2350.25, .santarem: 1466.08, .setubal: 1415.87, .vianaCastelo: 1179.85, .vilaReal: 1621.96, .viseu: 1195.72],
        .telecom: [.aveiro: 2727.67, .beja: 2120.85, .braga: 1796.5, .braganca: 2080.01, .casteloBranco: 2110.87, .coimbra: 2019.42, .evora: 2150.07, .faro: 1980.3, .guarda: 1741.35, .leiria: 1767.65, .lisboa: 2629.84, .portalegre: 1959.07, .porto: 2141.21, .santarem: 1664.73, .setubal: 2205.57, .vianaCastelo: 1852.85, .vilaReal: 2150.04, .viseu: 1994.75],
        .it: [.aveiro: 2257.44, .beja: 2081.71, .braga: 2273.07, .braganca: 1725.09, .casteloBranco: 1787.91, .coimbra: 2459.51, .evora: 1878.24, .faro: 2156.06, .guarda: 1971.34, .leiria: 2033.17, .lisboa: 2757.75, .portalegre: 1451.59, .porto: 2659.6, .santarem: 1679.21, .setubal: 1948.97, .vianaCastelo: 1512.19, .vilaReal: 1887.22, .viseu: 1786.95],
        .finance: [.aveiro: 2372.72, .beja: 2358.38, .braga: 2195.14, .braganca: 2323.82, .casteloBranco: 2235.52, .coimbra: 2302.21, .evora: 2362.51, .faro: 2315.45, .guarda: 2241.25, .leiria: 2396.74, .lisboa: 2924.56, .portalegre: 2205.38, .porto: 2519.54, .santarem: 2379.39, .setubal: 2380.03, .vianaCastelo: 2225.25, .vilaReal: 2287.15, .viseu: 2232.65],
        .realEstate: [.aveiro: 1293.67, .beja: 1267.51, .braga: 1268.24, .braganca: 1100.75, .casteloBranco: 1191.33, .coimbra: 1263.43, .evora: 1256.92, .faro: 1358.88, .guarda: 1193.1, .leiria: 1218.64, .lisboa: 1810.87, .portalegre: 1143.98, .porto: 1499.71, .santarem: 1295.32, .setubal: 1603.59, .vianaCastelo: 1208.86, .vilaReal: 1185.55, .viseu: 1154.07],
        .consulting: [.aveiro: 1625.36, .beja: 1554.04, .braga: 1512.83, .braganca: 1270.63, .casteloBranco: 1336.38, .coimbra: 1658.3, .evora: 1548.34, .faro: 1505.56, .guarda: 1263.07, .leiria: 1384.38, .lisboa: 2283.59, .portalegre: 1651.2, .porto: 1933.81, .santarem: 1458.23, .setubal: 1526.2, .vianaCastelo: 1456.99, .vilaReal: 1417.34, .viseu: 1509.81],
        .admin: [.aveiro: 1138.31, .beja: 1127.29, .braga: 1263.76, .braganca: 1079.65, .casteloBranco: 1267.86, .coimbra: 1381.18, .evora: 1282.66, .faro: 1179.16, .guarda: 1324.02, .leiria: 1192.18, .lisboa: 1407.74, .portalegre: 1070.93, .porto: 1477.77, .santarem: 1272.47, .setubal: 1281.88, .vianaCastelo: 1220.87, .vilaReal: 1110.39, .viseu: 1174.86],
        .publicAdmin: [.aveiro: 1113.79, .beja: 1335.24, .braga: 1176.16, .braganca: 1175.23, .casteloBranco: 1135.09, .coimbra: 1106.13, .evora: 1232.12, .faro: 1315.51, .guarda: 1116.39, .leiria: 1191.51, .lisboa: 2268.92, .portalegre: 1176.85, .porto: 1424.18, .santarem: 1166.78, .setubal: 1215.17, .vianaCastelo: 1111.78, .vilaReal: 1059.28, .viseu: 1121.11],
        .education: [.aveiro: 1766.78, .beja: 1323.98, .braga: 1643.35, .braganca: 1355.22, .casteloBranco: 1401.69, .coimbra: 1460.17, .evora: 1388.36, .faro: 1451.62, .guarda: 1287.24, .leiria: 1385.07, .lisboa: 1831.66, .portalegre: 1555.42, .porto: 1711.09, .santarem: 1386.99, .setubal: 1534.47, .vianaCastelo: 1374.77, .vilaReal: 1351.29, .viseu: 1367.58],
        .health: [.aveiro: 1210.87, .beja: 1569.39, .braga: 1627.04, .braganca: 2077.31, .casteloBranco: 1769.46, .coimbra: 1588.1, .evora: 1802.05, .faro: 1684.18, .guarda: 1744.83, .leiria: 1510.49, .lisboa: 1750.02, .portalegre: 1232.26, .porto: 1793.19, .santarem: 1747.66, .setubal: 1615.16, .vianaCastelo: 1736.82, .vilaReal: 1841.71, .viseu: 1660.3],
        .socialWork: [.aveiro: 1108.76, .beja: 1130.52, .braga: 1106.62, .braganca: 1097.98, .casteloBranco: 1067.26, .coimbra: 1112.24, .evora: 1155.02, .faro: 1121.3, .guarda: 1084.93, .leiria: 1078.28, .lisboa: 1229.82, .portalegre: 1091.54, .porto: 1141.41, .santarem: 1074.22, .setubal: 1109.19, .vianaCastelo: 1098.47, .vilaReal: 1074.61, .viseu: 1045.61],
        .arts: [.aveiro: 1540.24, .beja: 1216.63, .braga: 2435.36, .braganca: 1239.9, .casteloBranco: 1224.49, .coimbra: 1338.49, .evora: 1214.65, .faro: 1472.74, .guarda: 1235.22, .leiria: 1505.91, .lisboa: 1980.95, .portalegre: 1336.76, .porto: 2352.09, .santarem: 1213.43, .setubal: 6394.85, .vianaCastelo: 1119.37, .vilaReal: 1499.87, .viseu: 2038.96],
        .otherServices: [.aveiro: 1209.2, .beja: 1182.23, .braga: 1120.83, .braganca: 1188.47, .casteloBranco: 1232.37, .coimbra: 1279.33, .evora: 1341.25, .faro: 1171.84, .guarda: 1111.63, .leiria: 1143.7, .lisboa: 1608.82, .portalegre: 1202.63, .porto: 1354.99, .santarem: 1188.79, .setubal: 1163.34, .vianaCastelo: 1134.78, .vilaReal: 1177.65, .viseu: 1142.52],
    ]

    /// Employees in that sector and district (Quadro 61). Drives `isThin`.
    static let sectorCount: [Sector: [District: Int]] = [
        .agriculture: [.aveiro: 2227, .beja: 17135, .braga: 2693, .braganca: 927, .casteloBranco: 1831, .coimbra: 2182, .evora: 4373, .faro: 5984, .guarda: 1352, .leiria: 4242, .lisboa: 9136, .portalegre: 2347, .porto: 4475, .santarem: 7563, .setubal: 5737, .vianaCastelo: 1317, .vilaReal: 2138, .viseu: 4458],
        .extractive: [.aveiro: 314, .beja: 2245, .braga: 535, .braganca: 153, .casteloBranco: 259, .coimbra: 139, .evora: 373, .faro: 226, .guarda: 241, .leiria: 1154, .lisboa: 315, .portalegre: 89, .porto: 1165, .santarem: 677, .setubal: 177, .vianaCastelo: 302, .vilaReal: 419, .viseu: 356],
        .manufacturing: [.aveiro: 109226, .beja: 2604, .braga: 111056, .braganca: 2918, .casteloBranco: 10160, .coimbra: 23387, .evora: 8750, .faro: 5382, .guarda: 5028, .leiria: 42973, .lisboa: 68762, .portalegre: 4302, .porto: 139275, .santarem: 25074, .setubal: 32122, .vianaCastelo: 22538, .vilaReal: 5075, .viseu: 23283],
        .energy: [.aveiro: 207, .beja: 74, .braga: 346, .braganca: 78, .casteloBranco: 67, .coimbra: 341, .evora: 54, .faro: 175, .guarda: 86, .leiria: 163, .lisboa: 2886, .portalegre: 49, .porto: 1507, .santarem: 255, .setubal: 204, .vianaCastelo: 52, .vilaReal: 361, .viseu: 165],
        .water: [.aveiro: 1801, .beja: 562, .braga: 3032, .braganca: 320, .casteloBranco: 563, .coimbra: 1374, .evora: 296, .faro: 3265, .guarda: 228, .leiria: 1048, .lisboa: 6082, .portalegre: 348, .porto: 5673, .santarem: 1766, .setubal: 2070, .vianaCastelo: 589, .vilaReal: 500, .viseu: 743],
        .construction: [.aveiro: 13067, .beja: 2790, .braga: 39080, .braganca: 1900, .casteloBranco: 2954, .coimbra: 9812, .evora: 2936, .faro: 15686, .guarda: 2745, .leiria: 16313, .lisboa: 60051, .portalegre: 1585, .porto: 59476, .santarem: 10079, .setubal: 18994, .vianaCastelo: 7883, .vilaReal: 4111, .viseu: 18050],
        .autoTrade: [.aveiro: 5316, .beja: 774, .braga: 7459, .braganca: 755, .casteloBranco: 1222, .coimbra: 2824, .evora: 894, .faro: 3471, .guarda: 814, .leiria: 5126, .lisboa: 18431, .portalegre: 462, .porto: 15311, .santarem: 3059, .setubal: 3964, .vianaCastelo: 1565, .vilaReal: 1228, .viseu: 2345],
        .wholesale: [.aveiro: 12200, .beja: 1530, .braga: 13729, .braganca: 1115, .casteloBranco: 1858, .coimbra: 5248, .evora: 1791, .faro: 6614, .guarda: 1338, .leiria: 10790, .lisboa: 56375, .portalegre: 1409, .porto: 35087, .santarem: 6080, .setubal: 8035, .vianaCastelo: 2417, .vilaReal: 1332, .viseu: 3928],
        .retail: [.aveiro: 19078, .beja: 3678, .braga: 26207, .braganca: 2934, .casteloBranco: 4671, .coimbra: 12247, .evora: 4527, .faro: 23821, .guarda: 3737, .leiria: 15310, .lisboa: 93058, .portalegre: 2226, .porto: 64221, .santarem: 13297, .setubal: 26535, .vianaCastelo: 7181, .vilaReal: 4973, .viseu: 9546],
        .transport: [.aveiro: 9449, .beja: 808, .braga: 7452, .braganca: 561, .casteloBranco: 1143, .coimbra: 5373, .evora: 1310, .faro: 6639, .guarda: 1906, .leiria: 7185, .lisboa: 64765, .portalegre: 635, .porto: 30121, .santarem: 6866, .setubal: 10873, .vianaCastelo: 2256, .vilaReal: 1564, .viseu: 4601],
        .hospitality: [.aveiro: 11118, .beja: 3119, .braga: 13966, .braganca: 1729, .casteloBranco: 3343, .coimbra: 7895, .evora: 3869, .faro: 48139, .guarda: 2116, .leiria: 10471, .lisboa: 96536, .portalegre: 1644, .porto: 50691, .santarem: 7643, .setubal: 18193, .vianaCastelo: 5016, .vilaReal: 3532, .viseu: 6259],
        .media: [.aveiro: 372, .beja: 27, .braga: 850, .braganca: 44, .casteloBranco: 77, .coimbra: 460, .evora: 85, .faro: 219, .guarda: 41, .leiria: 335, .lisboa: 10883, .portalegre: 19, .porto: 3599, .santarem: 263, .setubal: 323, .vianaCastelo: 83, .vilaReal: 77, .viseu: 126],
        .telecom: [.aveiro: 308, .beja: 39, .braga: 509, .braganca: 32, .casteloBranco: 91, .coimbra: 233, .evora: 61, .faro: 281, .guarda: 27, .leiria: 150, .lisboa: 8455, .portalegre: 18, .porto: 1934, .santarem: 180, .setubal: 309, .vianaCastelo: 43, .vilaReal: 46, .viseu: 92],
        .it: [.aveiro: 2606, .beja: 95, .braga: 4087, .braganca: 162, .casteloBranco: 1552, .coimbra: 2482, .evora: 466, .faro: 970, .guarda: 247, .leiria: 1409, .lisboa: 63090, .portalegre: 58, .porto: 25309, .santarem: 712, .setubal: 1215, .vianaCastelo: 515, .vilaReal: 273, .viseu: 854],
        .finance: [.aveiro: 2391, .beja: 520, .braga: 3019, .braganca: 402, .casteloBranco: 590, .coimbra: 1489, .evora: 689, .faro: 1796, .guarda: 469, .leiria: 2120, .lisboa: 49618, .portalegre: 278, .porto: 12311, .santarem: 1470, .setubal: 1779, .vianaCastelo: 703, .vilaReal: 574, .viseu: 1209],
        .realEstate: [.aveiro: 1143, .beja: 223, .braga: 2348, .braganca: 113, .casteloBranco: 350, .coimbra: 756, .evora: 212, .faro: 4260, .guarda: 135, .leiria: 1096, .lisboa: 11497, .portalegre: 178, .porto: 5957, .santarem: 791, .setubal: 2274, .vianaCastelo: 387, .vilaReal: 294, .viseu: 977],
        .consulting: [.aveiro: 6783, .beja: 1026, .braga: 9345, .braganca: 671, .casteloBranco: 1375, .coimbra: 4545, .evora: 1323, .faro: 5614, .guarda: 744, .leiria: 6178, .lisboa: 87047, .portalegre: 878, .porto: 42574, .santarem: 3272, .setubal: 6311, .vianaCastelo: 1918, .vilaReal: 1397, .viseu: 3736],
        .admin: [.aveiro: 14136, .beja: 1039, .braga: 12615, .braganca: 352, .casteloBranco: 988, .coimbra: 6065, .evora: 1542, .faro: 15334, .guarda: 436, .leiria: 7757, .lisboa: 168379, .portalegre: 484, .porto: 65638, .santarem: 5291, .setubal: 17147, .vianaCastelo: 3735, .vilaReal: 594, .viseu: 3477],
        .publicAdmin: [.aveiro: 734, .beja: 455, .braga: 704, .braganca: 483, .casteloBranco: 470, .coimbra: 645, .evora: 383, .faro: 506, .guarda: 393, .leiria: 820, .lisboa: 3682, .portalegre: 212, .porto: 1521, .santarem: 673, .setubal: 1063, .vianaCastelo: 399, .vilaReal: 493, .viseu: 888],
        .education: [.aveiro: 4207, .beja: 546, .braga: 4818, .braganca: 281, .casteloBranco: 614, .coimbra: 1585, .evora: 478, .faro: 2329, .guarda: 570, .leiria: 2621, .lisboa: 25611, .portalegre: 258, .porto: 16419, .santarem: 1827, .setubal: 5228, .vianaCastelo: 898, .vilaReal: 479, .viseu: 1221],
        .health: [.aveiro: 4047, .beja: 1535, .braga: 10214, .braganca: 1591, .casteloBranco: 1716, .coimbra: 4665, .evora: 2113, .faro: 7636, .guarda: 1943, .leiria: 5006, .lisboa: 55440, .portalegre: 292, .porto: 31566, .santarem: 4743, .setubal: 8229, .vianaCastelo: 3104, .vilaReal: 2847, .viseu: 4161],
        .socialWork: [.aveiro: 12509, .beja: 3929, .braga: 11765, .braganca: 3625, .casteloBranco: 5032, .coimbra: 10933, .evora: 4575, .faro: 6955, .guarda: 5455, .leiria: 8977, .lisboa: 31265, .portalegre: 4157, .porto: 18853, .santarem: 9569, .setubal: 10615, .vianaCastelo: 4532, .vilaReal: 4523, .viseu: 8387],
        .arts: [.aveiro: 1730, .beja: 167, .braga: 2757, .braganca: 154, .casteloBranco: 330, .coimbra: 660, .evora: 317, .faro: 4266, .guarda: 108, .leiria: 1094, .lisboa: 12908, .portalegre: 109, .porto: 7425, .santarem: 580, .setubal: 2343, .vianaCastelo: 341, .vilaReal: 600, .viseu: 605],
        .otherServices: [.aveiro: 2342, .beja: 730, .braga: 4499, .braganca: 775, .casteloBranco: 821, .coimbra: 2298, .evora: 733, .faro: 2805, .guarda: 782, .leiria: 2106, .lisboa: 19689, .portalegre: 386, .porto: 9564, .santarem: 2563, .setubal: 4046, .vianaCastelo: 989, .vilaReal: 858, .viseu: 1585],
    ]

    /// All sectors together, per district. Used when no sector is chosen.
    static let districtMean: [District: Double] = [
        .aveiro: 1454.71, .beja: 1376.08, .braga: 1361.73, .braganca: 1251.51, .casteloBranco: 1279.53, .coimbra: 1422.03, .evora: 1371.98, .faro: 1320.21, .guarda: 1289.44, .leiria: 1392.79, .lisboa: 1896.51, .portalegre: 1295.36, .porto: 1583.93, .santarem: 1369.46, .setubal: 1560.37, .vianaCastelo: 1340.14, .vilaReal: 1278.46, .viseu: 1307.67,
    ]

    /// Continente mean across all sectors and districts.
    static let nationalMean: Double = 1582.74

    /// Continente mean for one sector (the TOTAL column of Quadro 110, which
    /// reconciles exactly with the sector totals already in SalaryDataset).
    static let sectorNationalMean: [Sector: Double] = [
        .agriculture: 1210.12, .extractive: 2021.23, .manufacturing: 1521.41, .energy: 3320.84,
        .water: 1478.51, .construction: 1336.73, .autoTrade: 1351.55, .wholesale: 1769.01,
        .retail: 1317.08, .transport: 1856.47, .hospitality: 1125.34, .media: 2262.35,
        .telecom: 2449.54, .it: 2628.75, .finance: 2718, .realEstate: 1535.48,
        .consulting: 1980.2, .admin: 1367.59, .publicAdmin: 1479.66, .education: 1682.53,
        .health: 1712.74, .socialWork: 1125.87, .arts: 2222.99, .otherServices: 1356.2,
    ]

    /// Below this many employees in the cell, the mean is too easily moved by a
    /// handful of people and the UI says so rather than colouring it confidently.
    /// 105 of the 432 cells fall here, almost all telecom, media and energy in
    /// interior districts (telecom in Portalegre is 18 workers).
    static let thinThreshold = 500

    static func mean(sector: Sector?, district: District) -> Double? {
        guard let sector else { return districtMean[district] }
        return sectorMean[sector]?[district]
    }

    static func count(sector: Sector?, district: District) -> Int? {
        guard let sector else { return nil }
        return sectorCount[sector]?[district]
    }

    static func isThin(sector: Sector?, district: District) -> Bool {
        guard let n = count(sector: sector, district: district) else { return false }
        return n < thinThreshold
    }

    /// The number every comparison on this screen is measured against.
    static func baseline(sector: Sector?, mode: MapBaseline, home: District?) -> Double? {
        switch mode {
        case .national:
            guard let sector else { return nationalMean }
            return sectorNationalMean[sector]
        case .home:
            guard let home else { return nil }
            return mean(sector: sector, district: home)
        }
    }
}

/// What the map's green and red are measured against.
enum MapBaseline: String, CaseIterable, Identifiable {
    /// The Continente average for that sector. Stable: the map looks the same
    /// whoever is holding the phone, and it shows the sector's real geography.
    case national
    /// The user's own district. Answers "where would I earn more", but for
    /// someone in Lisboa it paints almost everything red, because Lisboa is the
    /// best-paid district in most sectors.
    case home

    var id: String { rawValue }
}
