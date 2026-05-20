import SwiftUI

/// Default pet portrait when no user photo — matches the animal-type chips (colored fill + SF Symbol).
struct AnimalTypeDefaultAvatar: View {
    let animalType: AnimalType
    var cornerRadius: CGFloat? = nil

    private var iconPaddingRatio: CGFloat { 13.0 / 54.0 }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let padding = side * iconPaddingRatio
            ZStack {
                if let cornerRadius {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(animalType.color)
                } else {
                    Circle()
                        .fill(animalType.color)
                }
                Image(systemName: animalType.systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(padding)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PetAvatarView: View {
    let pet: Pet
    var size: CGFloat = 48
    /// When set, clips user photos and default icons to a rounded rect instead of a circle.
    var cornerRadius: CGFloat? = nil
    var glowColor: Color? = nil

    /// Zooms artwork before circular crop so JPEG fringe / anti-alias doesn’t read as a white ring.
    private static let cropOverscale: CGFloat = 1.14

    var body: some View {
        Group {
            if let data = pet.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                AnimalTypeDefaultAvatar(animalType: pet.animalType, cornerRadius: cornerRadius)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(pet.photoData == nil ? 1 : Self.cropOverscale)
        .clipShape(avatarClipShape)
    }

    private var avatarClipShape: AnyShape {
        if let cornerRadius {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            AnyShape(Circle())
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        PetAvatarView(pet: Pet(name: "Max",  animalType: .dog),  size: 56)
        PetAvatarView(pet: Pet(name: "Luna", animalType: .cat),  size: 56)
        PetAvatarView(pet: Pet(name: "Jill", animalType: .fish), size: 56)
    }
    .padding()
}
