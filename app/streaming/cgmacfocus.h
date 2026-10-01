#pragma once

// Cloud Gaming: o macOS tira o foco do jogo sem gerar evento SDL em alguns casos
// (Mission Control, troca de Space). Estes observadores enviam um SDL_USEREVENT
// com SDL_CODE_CG_RELEASE_CAPTURE para o loop da sessão soltar o mouse.

#define SDL_CODE_CG_RELEASE_CAPTURE 200

struct SDL_Window;

void CGMacFocus_Install(SDL_Window* window);
void CGMacFocus_Uninstall();

// O jogo está de fato na frente: app ativo, janela principal, visível e no Space atual.
bool CGMacFocus_GameIsFrontmost();
