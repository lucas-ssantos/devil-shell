pragma Singleton
import Quickshell
import Quickshell.Services.Polkit

// Serviço de autenticação polkit (singleton): registra este processo como o agente
// polkit da sessão (substitui polkit-gnome-authentication-agent-1/lxqt-policykit) e
// expõe o pedido de autenticação ativo (flow) para a PolkitWindow desenhar o diálogo.
// Só pode haver UM agente registrado por sessão — se outro já estiver rodando, o
// registro simplesmente falha e isRegistered fica false (sem erro fatal).
// A lógica de fila/conversa com o daemon fica toda dentro do PolkitAgent (C++); aqui
// só reexportamos o estado.
Singleton {
    id: svc
    readonly property alias isActive: agent.isActive
    readonly property alias isRegistered: agent.isRegistered
    readonly property alias flow: agent.flow

    PolkitAgent { id: agent }
}
