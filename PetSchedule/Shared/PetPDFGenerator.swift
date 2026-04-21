import UIKit

enum PetPDFGenerator {

    static func generate(for pet: Pet, scheduleItems: [ScheduleItem] = []) -> Data {
        let pageWidth: CGFloat  = 595   // A4 portrait
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // ── Header bar ───────────────────────────────────────────────────
            let pink = UIColor(red: 0.96, green: 0.33, blue: 0.53, alpha: 1)
            pink.setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentWidth, height: 56), cornerRadius: 12).fill()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let title = "\(pet.name)'s Health Record"
            let titleSize = (title as NSString).size(withAttributes: titleAttrs)
            (title as NSString).draw(
                at: CGPoint(x: margin + 16, y: y + (56 - titleSize.height) / 2),
                withAttributes: titleAttrs
            )

            // Date stamp top-right
            let dateStr = Date.now.formatted(date: .abbreviated, time: .omitted)
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let dateSize = (dateStr as NSString).size(withAttributes: dateAttrs)
            (dateStr as NSString).draw(
                at: CGPoint(x: pageWidth - margin - 16 - dateSize.width, y: y + (56 - dateSize.height) / 2),
                withAttributes: dateAttrs
            )
            y += 56 + 20

            // ── Pet photo + basics ────────────────────────────────────────────
            let photoSize: CGFloat = 80
            if let photoData = pet.photoData, let img = UIImage(data: photoData) {
                img.draw(in: CGRect(x: margin, y: y, width: photoSize, height: photoSize))
            } else {
                UIColor.systemGray5.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: photoSize, height: photoSize), cornerRadius: 10).fill()
            }

            let infoX = margin + photoSize + 16
            let infoW = contentWidth - photoSize - 16
            let bigNameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            (pet.name as NSString).draw(in: CGRect(x: infoX, y: y, width: infoW, height: 28), withAttributes: bigNameAttrs)

            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel
            ]
            var infoLines: [String] = [pet.animalDisplayName]
            if let age = pet.age { infoLines.append("Age: \(age)") }
            if let dob = pet.dateOfBirth {
                infoLines.append("DOB: \(dob.formatted(date: .abbreviated, time: .omitted))")
            }
            var lineY = y + 30
            for line in infoLines {
                (line as NSString).draw(in: CGRect(x: infoX, y: lineY, width: infoW, height: 18), withAttributes: subtitleAttrs)
                lineY += 18
            }
            y += max(photoSize, lineY - y) + 20

            // ── Section helper ────────────────────────────────────────────────
            func drawSection(_ heading: String) {
                let headAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: pink
                ]
                (heading.uppercased() as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: headAttrs)
                y += 18
                UIColor.systemGray4.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: 0.5)).fill()
                y += 8
            }

            func drawBody(_ text: String) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]
                let ns = text as NSString
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: 600)
                let needed = ns.boundingRect(with: CGSize(width: contentWidth, height: 600),
                                             options: .usesLineFragmentOrigin,
                                             attributes: attrs, context: nil)
                ns.draw(in: rect, withAttributes: attrs)
                y += needed.height + 12
            }

            // ── Notes ─────────────────────────────────────────────────────────
            if !pet.notes.isEmpty {
                drawSection("Notes")
                drawBody(pet.notes)
                y += 4
            }

            // ── Vet Details ───────────────────────────────────────────────────
            if !pet.vetDetails.isEmpty {
                drawSection("Vet Details")
                var vetLines: [String] = []
                if !pet.vetDetails.organisation.isEmpty { vetLines.append(pet.vetDetails.organisation) }
                if !pet.vetDetails.address.isEmpty      { vetLines.append(pet.vetDetails.address) }
                if !pet.vetDetails.phone.isEmpty        { vetLines.append("Phone: \(pet.vetDetails.phone)") }
                if !pet.vetDetails.email.isEmpty        { vetLines.append("Email: \(pet.vetDetails.email)") }
                drawBody(vetLines.joined(separator: "\n"))
                y += 4
            }

            // ── Weight History ────────────────────────────────────────────────
            if !pet.weightHistory.isEmpty {
                drawSection("Weight History")
                let wUnit = WeightUnit.current
                let sorted = pet.weightHistory.sorted { $0.date < $1.date }
                let rows = sorted.map { "\($0.date.formatted(date: .abbreviated, time: .omitted))   \(wUnit.formatValue($0.kg))" }
                drawBody(rows.joined(separator: "\n"))
                y += 4
            }

            // ── Height History ────────────────────────────────────────────────
            if !pet.heightHistory.isEmpty {
                drawSection("Height History")
                let hUnit = HeightUnit.current
                let sorted = pet.heightHistory.sorted { $0.date < $1.date }
                let rows = sorted.map { "\($0.date.formatted(date: .abbreviated, time: .omitted))   \(hUnit.formatValue($0.cm))" }
                drawBody(rows.joined(separator: "\n"))
                y += 4
            }

            // ── Medicine Compliance ───────────────────────────────────────────
            let medItems = scheduleItems
                .filter { $0.pet.id == pet.id && $0.isMedicineEvent }
                .sorted { $0.time > $1.time }
                .prefix(30)
            if !medItems.isEmpty {
                drawSection("Medicine Compliance")

                // Compliance summary line
                let total    = medItems.count
                let taken    = medItems.filter { $0.medicineAccepted == true }.count
                let skipped  = medItems.filter { $0.medicineAccepted == false }.count
                let pending  = medItems.filter { $0.medicineAccepted == nil }.count
                let pctStr   = total > 0 ? "\(Int(Double(taken) / Double(total) * 100))%" : "N/A"
                drawBody("Overall: \(pctStr) compliance (\(taken) taken, \(skipped) skipped, \(pending) pending)")

                // Per-day rows
                let cal = Calendar.current
                let grouped = Dictionary(grouping: medItems) { cal.startOfDay(for: $0.time) }
                let days = grouped.keys.sorted { $0 > $1 }
                var logLines: [String] = []
                for day in days {
                    let dayItems = grouped[day]!.sorted { $0.time < $1.time }
                    for item in dayItems {
                        let dateStr = day.formatted(date: .abbreviated, time: .omitted)
                        let timeStr = item.isAllDay ? "All day" : item.time.formatted(date: .omitted, time: .shortened)
                        let status: String
                        switch item.medicineAccepted {
                        case true:  status = "Yes — taken"
                        case false: status = "No — skipped"
                        case nil:   status = item.isCompleted ? "Done" : "Pending"
                        }
                        logLines.append("\(dateStr)  \(timeStr)  \(item.activityName)  →  \(status)")
                    }
                }
                drawBody(logLines.joined(separator: "\n"))
                y += 4
            }

            // ── Recent Schedule ───────────────────────────────────────────────
            let recent = scheduleItems
                .filter { $0.pet.id == pet.id && !$0.isMedicineEvent }
                .sorted { $0.time > $1.time }
                .prefix(10)
            if !recent.isEmpty {
                drawSection("Recent Events")
                let rows = recent.map { item -> String in
                    let status = item.isCompleted ? "✓" : "○"
                    let t = item.isAllDay ? "All day" : item.time.formatted(date: .abbreviated, time: .shortened)
                    return "\(status)  \(item.activityName)  —  \(t)"
                }
                drawBody(rows.joined(separator: "\n"))
            }

            // ── Footer ────────────────────────────────────────────────────────
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let footer = "Generated by PetSchedule • \(Date.now.formatted())"
            (footer as NSString).draw(
                at: CGPoint(x: margin, y: pageHeight - 28),
                withAttributes: footerAttrs
            )
        }
    }
}
