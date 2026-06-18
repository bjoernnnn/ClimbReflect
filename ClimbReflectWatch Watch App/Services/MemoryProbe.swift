import Foundation

enum MemoryProbe {
    /// Aktueller phys_footprint (Jetsam-relevante Größe) in MB.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / 1_048_576.0
    }

    /// Verfügbarer Speicher bis zum Prozess-Limit in MB (kleiner = näher am Kill).
    static func availableMB() -> Double {
        return Double(os_proc_available_memory()) / 1_048_576.0
    }
}
