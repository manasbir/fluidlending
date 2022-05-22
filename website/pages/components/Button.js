import React from 'react';

const Button = ({ children, onClick, className, style }) => {
    return <button onClick={onClick} className={className} style={style}>
        {children}
    </button>
}

export default Button;