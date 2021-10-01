import Foundation

protocol UserDefaultsPrimitive {}

extension Bool: UserDefaultsPrimitive {}
extension Int: UserDefaultsPrimitive {}
extension Float: UserDefaultsPrimitive {}
extension Double: UserDefaultsPrimitive {}
extension String: UserDefaultsPrimitive {}
extension Data: UserDefaultsPrimitive {}
extension Array: UserDefaultsPrimitive where Element: UserDefaultsPrimitive {}
extension Dictionary: UserDefaultsPrimitive where Key == String, Value: UserDefaultsPrimitive {}
