export interface User {
    _id: string;
    name: string;
    email: string;
    role: 'user' | 'admin';
    subscriptionStatus: 'free' | 'premium' | 'pro';
    subscriptionExpiry?: string;
    isSuspended: boolean;
    recoveryKey?: string;
    createdAt?: string;
    updatedAt?: string;
}

export interface Payment {
    _id: string;
    userId: string;
    user?: {
        _id: string;
        name: string;
        email: string;
    };
    userEmail?: string; // Populated sometimes
    amount: number;
    currency: string;
    status: 'pending' | 'completed' | 'failed' | 'refunded';
    date: string;
    transactionId?: string;
    paymentMethod?: string;
    orderId?: string;
    plan?: string;
}

export interface SupportTicket {
    _id: string;
    userId: string;
    user?: {
        _id: string;
        name: string;
        email: string;
    };
    userEmail?: string;
    subject: string;
    message: string;
    status: 'open' | 'closed' | 'pending';
    replies: TicketReply[];
    createdAt: string;
    updatedAt: string;
}

export interface TicketReply {
    sender: 'user' | 'admin';
    message: string;
    date: string;
}

export interface VaultItem {
    _id: string;
    userId: string;
    name: string;
    type: 'file' | 'folder' | 'note';
    size?: string;
    content?: string; // For notes
    url?: string;
    isDeleted: boolean;
    createdAt: string;
    updatedAt: string;
}
