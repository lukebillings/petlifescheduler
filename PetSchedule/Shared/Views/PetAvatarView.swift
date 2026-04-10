import SwiftUI

struct PetAvatarView: View {
    let pet: Pet
    var size: CGFloat = 48

    var body: some View {
        Circle()
            .fill(pet.color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: pet.systemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(.white)
            }
            .shadow(color: pet.color.opacity(0.4), radius: 4, y: 2)
    }
}

#Preview {
    HStack(spacing: 12) {
        PetAvatarView(pet: Pet(name: "Max",  color: .orange, systemImage: "dog.fill"),  size: 56)
        PetAvatarView(pet: Pet(name: "Luna", color: .purple, systemImage: "cat.fill"),  size: 56)
        PetAvatarView(pet: Pet(name: "Nemo", color: .cyan,   systemImage: "fish.fill"), size: 56)
    }
    .padding()
}
