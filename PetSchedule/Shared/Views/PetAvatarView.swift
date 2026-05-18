import SwiftUI

struct PetAvatarView: View {
    let pet: Pet
    var size: CGFloat = 48
    var glowColor: Color? = nil

    /// Zooms artwork before circular crop so JPEG fringe / anti-alias doesn’t read as a white ring.
    private static let cropOverscale: CGFloat = 1.14

    var body: some View {
        ZStack {
            if let data = pet.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Image(pet.animalType.placeholderImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(Self.cropOverscale)
        .clipShape(Circle())
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
