import SwiftUI

struct PetAvatarView: View {
    let pet: Pet
    var size: CGFloat = 48
    var glowColor: Color? = nil

    var body: some View {
        ZStack {
            if let data = pet.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(pet.animalType.placeholderImage)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: (glowColor ?? Color.appPink).opacity(0.5), radius: 12, y: 4)
    }
}

#Preview {
    HStack(spacing: 12) {
        PetAvatarView(pet: Pet(name: "Max",  animalType: .dog),  size: 56)
        PetAvatarView(pet: Pet(name: "Luna", animalType: .cat),  size: 56)
        PetAvatarView(pet: Pet(name: "Nemo", animalType: .fish), size: 56)
    }
    .padding()
}
