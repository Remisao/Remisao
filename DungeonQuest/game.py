import pygame
import random
import sys

# --- Constantes ---
LARGEUR = 800
HAUTEUR = 600
FPS = 60
TAILLE_CASE = 40

# Couleurs
NOIR = (0, 0, 0)
BLANC = (255, 255, 255)
ROUGE = (200, 50, 50)
VERT = (50, 200, 50)
BLEU = (50, 100, 200)
JAUNE = (230, 200, 50)
GRIS = (80, 80, 80)
GRIS_CLAIR = (160, 160, 160)
VIOLET = (150, 50, 200)
ORANGE = (230, 130, 30)

# --- Classes ---

class Joueur:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.vitesse = 3
        self.vie = 100
        self.vie_max = 100
        self.score = 0
        self.invincible = 0  # frames d'invincibilite apres un coup

    def deplacer(self, touches, murs):
        dx, dy = 0, 0
        if touches[pygame.K_LEFT] or touches[pygame.K_q]:
            dx = -self.vitesse
        if touches[pygame.K_RIGHT] or touches[pygame.K_d]:
            dx = self.vitesse
        if touches[pygame.K_UP] or touches[pygame.K_z]:
            dy = -self.vitesse
        if touches[pygame.K_DOWN] or touches[pygame.K_s]:
            dy = self.vitesse

        # Collision avec les murs
        rect_futur_x = pygame.Rect(self.x + dx, self.y, 30, 30)
        rect_futur_y = pygame.Rect(self.x, self.y + dy, 30, 30)
        for mur in murs:
            if rect_futur_x.colliderect(mur):
                dx = 0
            if rect_futur_y.colliderect(mur):
                dy = 0

        # Limites de l'ecran
        self.x = max(0, min(LARGEUR - 30, self.x + dx))
        self.y = max(0, min(HAUTEUR - 30, self.y + dy))

        if self.invincible > 0:
            self.invincible -= 1

    def rect(self):
        return pygame.Rect(self.x, self.y, 30, 30)

    def dessiner(self, surface):
        # Corps
        couleur = BLEU if self.invincible % 6 < 3 else GRIS_CLAIR
        pygame.draw.rect(surface, couleur, (self.x, self.y, 30, 30), border_radius=6)
        # Yeux
        pygame.draw.circle(surface, BLANC, (self.x + 10, self.y + 10), 5)
        pygame.draw.circle(surface, BLANC, (self.x + 22, self.y + 10), 5)
        pygame.draw.circle(surface, NOIR, (self.x + 11, self.y + 10), 2)
        pygame.draw.circle(surface, NOIR, (self.x + 23, self.y + 10), 2)


class Ennemi:
    def __init__(self, x, y):
        self.x = float(x)
        self.y = float(y)
        self.vitesse = 1.2
        self.vie = 3
        self.timer = 0

    def deplacer(self, joueur, murs):
        self.timer += 1
        # Se deplace vers le joueur toutes les 2 frames
        if self.timer % 2 == 0:
            dx = joueur.x - self.x
            dy = joueur.y - self.y
            dist = max(1, (dx**2 + dy**2) ** 0.5)
            mvx = self.vitesse * dx / dist
            mvy = self.vitesse * dy / dist

            rect_x = pygame.Rect(self.x + mvx, self.y, 28, 28)
            rect_y = pygame.Rect(self.x, self.y + mvy, 28, 28)
            peut_x = all(not rect_x.colliderect(m) for m in murs)
            peut_y = all(not rect_y.colliderect(m) for m in murs)

            if peut_x:
                self.x += mvx
            if peut_y:
                self.y += mvy

    def rect(self):
        return pygame.Rect(int(self.x), int(self.y), 28, 28)

    def dessiner(self, surface):
        pygame.draw.rect(surface, ROUGE, (int(self.x), int(self.y), 28, 28), border_radius=5)
        # Yeux menaçants
        pygame.draw.circle(surface, JAUNE, (int(self.x) + 8, int(self.y) + 9), 4)
        pygame.draw.circle(surface, JAUNE, (int(self.x) + 20, int(self.y) + 9), 4)
        pygame.draw.circle(surface, NOIR, (int(self.x) + 9, int(self.y) + 9), 2)
        pygame.draw.circle(surface, NOIR, (int(self.x) + 21, int(self.y) + 9), 2)


class Potion:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.active = True

    def rect(self):
        return pygame.Rect(self.x, self.y, 20, 20)

    def dessiner(self, surface):
        if self.active:
            pygame.draw.ellipse(surface, VERT, (self.x, self.y, 20, 20))
            pygame.draw.ellipse(surface, BLANC, (self.x + 5, self.y + 4, 8, 8))


class Piece:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.active = True
        self.anim = 0

    def rect(self):
        return pygame.Rect(self.x, self.y, 18, 18)

    def dessiner(self, surface):
        if self.active:
            self.anim = (self.anim + 1) % 30
            r = 9 + (2 if self.anim < 15 else 0)
            pygame.draw.circle(surface, JAUNE, (self.x + 9, self.y + 9), r)
            pygame.draw.circle(surface, ORANGE, (self.x + 9, self.y + 9), r - 4)


# --- Fonctions utilitaires ---

def generer_murs():
    murs = []
    # Bordures
    for x in range(0, LARGEUR, TAILLE_CASE):
        murs.append(pygame.Rect(x, 0, TAILLE_CASE, TAILLE_CASE))
        murs.append(pygame.Rect(x, HAUTEUR - TAILLE_CASE, TAILLE_CASE, TAILLE_CASE))
    for y in range(0, HAUTEUR, TAILLE_CASE):
        murs.append(pygame.Rect(0, y, TAILLE_CASE, TAILLE_CASE))
        murs.append(pygame.Rect(LARGEUR - TAILLE_CASE, y, TAILLE_CASE, TAILLE_CASE))

    # Murs interieurs aleatoires
    positions_libres = set()
    for x in range(2, (LARGEUR // TAILLE_CASE) - 2):
        for y in range(2, (HAUTEUR // TAILLE_CASE) - 2):
            positions_libres.add((x, y))

    # Zone de depart libre (autour du joueur)
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            positions_libres.discard((5 + dx, 5 + dy))

    nb_murs = 30
    choix = random.sample(list(positions_libres), nb_murs)
    for (cx, cy) in choix:
        murs.append(pygame.Rect(cx * TAILLE_CASE, cy * TAILLE_CASE, TAILLE_CASE, TAILLE_CASE))

    return murs


def generer_objets(murs):
    ennemis, potions, pieces = [], [], []
    rects_murs = murs

    def position_libre(rx, ry, w, h):
        r = pygame.Rect(rx, ry, w, h)
        return all(not r.colliderect(m) for m in rects_murs)

    # Ennemis
    for _ in range(6):
        for _ in range(100):
            x = random.randint(TAILLE_CASE, LARGEUR - 2 * TAILLE_CASE)
            y = random.randint(TAILLE_CASE, HAUTEUR - 2 * TAILLE_CASE)
            # Loin du joueur
            if (x - 200) ** 2 + (y - 200) ** 2 > 150 ** 2 and position_libre(x, y, 28, 28):
                ennemis.append(Ennemi(x, y))
                break

    # Potions
    for _ in range(5):
        for _ in range(100):
            x = random.randint(TAILLE_CASE, LARGEUR - 2 * TAILLE_CASE)
            y = random.randint(TAILLE_CASE, HAUTEUR - 2 * TAILLE_CASE)
            if position_libre(x, y, 20, 20):
                potions.append(Potion(x, y))
                break

    # Pieces
    for _ in range(12):
        for _ in range(100):
            x = random.randint(TAILLE_CASE, LARGEUR - 2 * TAILLE_CASE)
            y = random.randint(TAILLE_CASE, HAUTEUR - 2 * TAILLE_CASE)
            if position_libre(x, y, 18, 18):
                pieces.append(Piece(x, y))
                break

    return ennemis, potions, pieces


def dessiner_hud(surface, joueur, police):
    # Barre de vie
    pygame.draw.rect(surface, GRIS, (20, 15, 200, 20), border_radius=5)
    largeur_vie = int(200 * joueur.vie / joueur.vie_max)
    couleur_vie = VERT if joueur.vie > 50 else (JAUNE if joueur.vie > 25 else ROUGE)
    pygame.draw.rect(surface, couleur_vie, (20, 15, largeur_vie, 20), border_radius=5)
    pygame.draw.rect(surface, BLANC, (20, 15, 200, 20), 2, border_radius=5)

    texte_vie = police.render(f"Vie: {joueur.vie}/{joueur.vie_max}", True, BLANC)
    surface.blit(texte_vie, (230, 15))

    texte_score = police.render(f"Score: {joueur.score}", True, JAUNE)
    surface.blit(texte_score, (LARGEUR - 160, 15))


def dessiner_fond(surface, murs):
    surface.fill((20, 20, 35))
    # Grille subtile
    for x in range(0, LARGEUR, TAILLE_CASE):
        pygame.draw.line(surface, (30, 30, 50), (x, 0), (x, HAUTEUR))
    for y in range(0, HAUTEUR, TAILLE_CASE):
        pygame.draw.line(surface, (30, 30, 50), (0, y), (LARGEUR, y))
    # Murs
    for mur in murs:
        pygame.draw.rect(surface, GRIS, mur)
        pygame.draw.rect(surface, GRIS_CLAIR, mur, 2)


def ecran_titre(surface, police_grande, police):
    surface.fill((10, 10, 25))
    titre = police_grande.render("DUNGEON QUEST", True, JAUNE)
    surface.blit(titre, (LARGEUR // 2 - titre.get_width() // 2, 150))

    lignes = [
        "Z/Q/S/D ou fleches : se deplacer",
        "Ramasse les pieces (jaune) : +10 pts",
        "Ramasse les potions (vert) : +vie",
        "Evite les ennemis (rouge) !",
        "",
        "Appuie sur ENTREE pour jouer",
    ]
    for i, ligne in enumerate(lignes):
        t = police.render(ligne, True, BLANC)
        surface.blit(t, (LARGEUR // 2 - t.get_width() // 2, 280 + i * 35))


def ecran_game_over(surface, police_grande, police, score):
    surface.fill((15, 5, 5))
    t1 = police_grande.render("GAME OVER", True, ROUGE)
    surface.blit(t1, (LARGEUR // 2 - t1.get_width() // 2, 200))
    t2 = police.render(f"Score final : {score}", True, JAUNE)
    surface.blit(t2, (LARGEUR // 2 - t2.get_width() // 2, 300))
    t3 = police.render("Appuie sur R pour rejouer ou ECHAP pour quitter", True, BLANC)
    surface.blit(t3, (LARGEUR // 2 - t3.get_width() // 2, 380))


# --- Boucle principale ---

def main():
    pygame.init()
    surface = pygame.display.set_mode((LARGEUR, HAUTEUR))
    pygame.display.set_caption("Dungeon Quest")
    horloge = pygame.time.Clock()

    police = pygame.font.SysFont("monospace", 20)
    police_grande = pygame.font.SysFont("monospace", 52, bold=True)

    etat = "titre"  # "titre", "jeu", "gameover"
    joueur = None
    murs = []
    ennemis = []
    potions = []
    pieces = []

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

            if event.type == pygame.KEYDOWN:
                if etat == "titre" and event.key == pygame.K_RETURN:
                    # Nouvelle partie
                    murs = generer_murs()
                    ennemis, potions, pieces = generer_objets(murs)
                    joueur = Joueur(200, 200)
                    etat = "jeu"

                elif etat == "gameover":
                    if event.key == pygame.K_r:
                        murs = generer_murs()
                        ennemis, potions, pieces = generer_objets(murs)
                        joueur = Joueur(200, 200)
                        etat = "jeu"
                    elif event.key == pygame.K_ESCAPE:
                        pygame.quit()
                        sys.exit()

        if etat == "titre":
            ecran_titre(surface, police_grande, police)

        elif etat == "jeu":
            touches = pygame.key.get_pressed()
            joueur.deplacer(touches, murs)

            # Deplacer ennemis
            for ennemi in ennemis:
                ennemi.deplacer(joueur, murs)

            # Collision joueur / ennemis
            for ennemi in ennemis:
                if joueur.invincible == 0 and joueur.rect().colliderect(ennemi.rect()):
                    joueur.vie -= 20
                    joueur.invincible = 60  # 1 seconde d'invincibilite
                    if joueur.vie <= 0:
                        etat = "gameover"

            # Ramasser potions
            for potion in potions:
                if potion.active and joueur.rect().colliderect(potion.rect()):
                    potion.active = False
                    joueur.vie = min(joueur.vie_max, joueur.vie + 30)
                    joueur.score += 5

            # Ramasser pieces
            for piece in pieces:
                if piece.active and joueur.rect().colliderect(piece.rect()):
                    piece.active = False
                    joueur.score += 10

            # Dessin
            dessiner_fond(surface, murs)
            for potion in potions:
                potion.dessiner(surface)
            for piece in pieces:
                piece.dessiner(surface)
            for ennemi in ennemis:
                ennemi.dessiner(surface)
            joueur.dessiner(surface)
            dessiner_hud(surface, joueur, police)

            # Message si toutes pieces ramassees
            if all(not p.active for p in pieces):
                msg = police_grande.render("VICTOIRE !", True, JAUNE)
                surface.blit(msg, (LARGEUR // 2 - msg.get_width() // 2, HAUTEUR // 2 - 40))
                msg2 = police.render("Appuie sur R pour rejouer", True, BLANC)
                surface.blit(msg2, (LARGEUR // 2 - msg2.get_width() // 2, HAUTEUR // 2 + 30))
                touches_raw = pygame.key.get_pressed()
                if touches_raw[pygame.K_r]:
                    murs = generer_murs()
                    ennemis, potions, pieces = generer_objets(murs)
                    joueur.x, joueur.y = 200, 200

        elif etat == "gameover":
            ecran_game_over(surface, police_grande, police, joueur.score)

        pygame.display.flip()
        horloge.tick(FPS)


if __name__ == "__main__":
    main()
